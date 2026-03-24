import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isCapturingShortcut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let error = appState.lastErrorMessage, !error.isEmpty {
                    SettingsWarningCard(
                        title: "Warning",
                        message: error,
                        dismiss: { appState.clearError() }
                    )
                }

                SettingsCard(title: "Shortcut") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Shortcut", selection: presetShortcutBinding) {
                            ForEach(ShortcutPreset.allCases) { preset in
                                Text(preset.label).tag(preset)
                            }
                        }

                        Text(presetSubtitle(ShortcutPreset(from: appState.preferences.shortcut)))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        if appState.preferences.shortcut.triggerKey == .customShortcut || isCapturingShortcut {
                            HStack {
                                Text("Current")
                                Spacer()
                                Text(appState.preferences.shortcut.displayName)
                                    .foregroundStyle(.secondary)
                            }

                            ShortcutCaptureButton(
                                isCapturing: $isCapturingShortcut,
                                currentTitle: appState.preferences.shortcut.displayName
                            ) { shortcut in
                                appState.updateShortcut(shortcut)
                                isCapturingShortcut = false
                            }
                        }
                    }
                }

                SettingsCard(title: "Permissions") {
                    PermissionRow(
                        title: "Microphone",
                        status: appState.permissionState.microphone.rawValue,
                        primaryAction: { Task { await appState.requestMicrophonePermission() } },
                        secondaryAction: { appState.openAccessibilitySettings() },
                        primaryTitle: "Request",
                        secondaryTitle: "System Settings"
                    )

                    PermissionRow(
                        title: "Accessibility",
                        status: appState.permissionState.accessibility.rawValue,
                        primaryAction: { appState.requestAccessibilityPermission() },
                        secondaryAction: { appState.openAccessibilitySettings() },
                        primaryTitle: "Prompt",
                        secondaryTitle: "System Settings"
                    )

                    PermissionInfoRow(
                        title: "Input Monitoring",
                        status: appState.permissionState.inputMonitoring.rawValue,
                        action: { appState.openInputMonitoringSettings() },
                        actionTitle: "System Settings"
                    )

                    Text("If Listener is running from Terminal or `swift run`, macOS may show Terminal in Privacy settings until the app is packaged as its own app bundle.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                SettingsCard(title: "Audio") {
                    Picker("Microphone", selection: microphoneSelectionBinding) {
                        Text("System Default").tag(Optional<UInt32>.none)
                        ForEach(appState.availableMicrophones, id: \.stableID) { microphone in
                            Text(microphone.displayName).tag(Optional(microphone.stableID))
                        }
                    }

                    Text("Pick a specific input device, or leave Listener on the macOS default microphone.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Refresh", action: appState.refreshMicrophones)
                            .buttonStyle(.bordered)
                    }
                }

                SettingsCard(title: "Whisper") {
                    InstallStatusRow(
                        title: "Base English",
                        state: appState.whisperSetupState,
                        primaryTitle: "Download",
                        primaryAction: { appState.downloadWhisperSetup() },
                        secondaryTitle: "Reveal",
                        secondaryAction: { appState.revealWhisperFiles() }
                    )

                    Stepper(
                        "Auto-unload after \(Int(appState.preferences.workerIdleTimeout))s",
                        value: idleTimeoutBinding,
                        in: 15...600,
                        step: 15
                    )
                }

                SettingsCard(title: "Accuracy") {
                    Text("Quiet-speech enhancement runs automatically before transcription. Add custom coding, directory, and application terms below to improve recognition.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text("Custom Vocabulary")
                        .font(.system(size: 14, weight: .semibold))

                    TextEditor(text: Binding(
                        get: { appState.accuracyVocabularyText },
                        set: { appState.updateAccuracyVocabularyText($0) }
                    ))
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 140)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.08))
                    )

                    HStack {
                        Button("Import", action: appState.importAccuracyVocabulary)
                            .buttonStyle(.bordered)
                        Button("Export", action: appState.exportAccuracyVocabulary)
                            .buttonStyle(.bordered)
                        Button("Reset", action: appState.resetAccuracyVocabulary)
                            .buttonStyle(.bordered)
                    }
                }
                SettingsCard(title: "System") {
                    Toggle("Launch at login", isOn: Binding(
                        get: { appState.isLaunchAtLoginEnabled },
                        set: { appState.setLaunchAtLogin(enabled: $0) }
                    ))
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var idleTimeoutBinding: Binding<Double> {
        Binding(
            get: { appState.preferences.workerIdleTimeout },
            set: { appState.updateIdleTimeout($0) }
        )
    }

    private var microphoneSelectionBinding: Binding<UInt32?> {
        Binding(
            get: { appState.preferences.selectedMicrophoneID },
            set: { appState.updateSelectedMicrophoneID($0) }
        )
    }

    private var presetShortcutBinding: Binding<ShortcutPreset> {
        Binding(
            get: { ShortcutPreset(from: appState.preferences.shortcut) },
            set: { preset in
                switch preset {
                case .optionFn:
                    isCapturingShortcut = false
                    appState.updateShortcut(.default)
                case .fn:
                    isCapturingShortcut = false
                    appState.updateShortcut(.fnOnly)
                case .rightCommand:
                    isCapturingShortcut = false
                    appState.updateShortcut(.rightCommand)
                case .rightOption:
                    isCapturingShortcut = false
                    appState.updateShortcut(.rightOption)
                case .custom:
                    isCapturingShortcut = true
                    if appState.preferences.shortcut.triggerKey != .customShortcut {
                        appState.updateShortcut(.custom(keyCode: 0, modifiers: [], keyDisplay: "Not Set"))
                    }
                }
            }
        )
    }

    private func presetSubtitle(_ preset: ShortcutPreset) -> String {
        switch preset {
        case .optionFn:
            return "Default. Harder to trigger by accident."
        case .fn:
            return "Simplest hold-to-talk option."
        case .rightCommand:
            return "Good fallback if Fn is unreliable."
        case .rightOption:
            return "Another easy-to-reach fallback."
        case .custom:
            return "Record any key or key combo you want."
        }
    }

}

enum ShortcutPreset: String, CaseIterable, Identifiable {
    case optionFn
    case fn
    case rightCommand
    case rightOption
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .optionFn:
            return "Option + Fn"
        case .fn:
            return "Fn"
        case .rightCommand:
            return "Right Command"
        case .rightOption:
            return "Right Option"
        case .custom:
            return "Custom Shortcut"
        }
    }

    init(from shortcut: ShortcutSpec) {
        switch shortcut.triggerKey {
        case .optionFn:
            self = .optionFn
        case .fn:
            self = .fn
        case .rightCommand:
            self = .rightCommand
        case .rightOption:
            self = .rightOption
        case .customShortcut:
            self = .custom
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

struct SettingsWarningCard: View {
    let title: String
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .padding(10)
                .background(Circle().fill(Color.orange.opacity(0.9)))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Dismiss", action: dismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.18),
                            Color.red.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.orange.opacity(0.24), lineWidth: 1)
                )
        )
    }
}

struct PermissionRow: View {
    let title: String
    let status: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let primaryTitle: String
    let secondaryTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(status)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PermissionInfoRow: View {
    let title: String
    let status: String
    let action: () -> Void
    let actionTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(status)
                    .foregroundStyle(.secondary)
            }

            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

struct InstallStatusRow: View {
    let title: String
    let state: InstallProgressState
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(statusText)
                    .foregroundStyle(statusColor)
            }

            HStack {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private var isWorking: Bool {
        if case .working = state { return true }
        return false
    }

    private var statusText: String {
        switch state {
        case .idle:
            return "Not installed"
        case .working(let message), .success(let message), .failure(let message):
            return message
        }
    }

    private var statusColor: Color {
        switch state {
        case .success:
            return .green
        case .failure:
            return .orange
        case .working:
            return .secondary
        case .idle:
            return .secondary
        }
    }
}

struct ShortcutCaptureButton: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let currentTitle: String
    let onCapture: (ShortcutSpec) -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "Record Custom Shortcut", target: context.coordinator, action: #selector(Coordinator.toggleCapture))
        button.bezelStyle = .rounded
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
        button.title = isCapturing ? "Press a shortcut…" : "Change Custom Shortcut"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: ShortcutCaptureButton
        weak var button: NSButton?
        private var monitor: Any?

        init(parent: ShortcutCaptureButton) {
            self.parent = parent
        }

        @objc func toggleCapture() {
            if parent.isCapturing {
                stopCapture()
            } else {
                startCapture()
            }
        }

        private func startCapture() {
            parent.isCapturing = true
            button?.window?.makeFirstResponder(button)
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                if event.keyCode == UInt16(kVK_Escape) {
                    self.stopCapture()
                    return nil
                }
                let modifiers = EventModifiers(nsFlags: event.modifierFlags, removingTriggerFor: .customShortcut)
                let display = Self.displayName(for: event)
                self.parent.onCapture(.custom(keyCode: event.keyCode, modifiers: modifiers, keyDisplay: display))
                self.stopCapture()
                return nil
            }
        }

        private func stopCapture() {
            parent.isCapturing = false
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private static func displayName(for event: NSEvent) -> String {
            if let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines),
               !characters.isEmpty {
                return characters.uppercased()
            }
            return "Key \(event.keyCode)"
        }
    }
}
