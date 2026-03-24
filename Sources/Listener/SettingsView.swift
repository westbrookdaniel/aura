import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isCapturingShortcut = false

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeaderView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error = appState.lastErrorMessage, !error.isEmpty {
                        SettingsWarningCard(
                            title: "Warning",
                            message: error,
                            dismiss: { appState.clearError() }
                        )
                    }

                    if appState.isSetupFlowPresented || !appState.isSetupComplete {
                        SetupFlowCard(appState: appState)
                    }

                    SettingsCard {
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

                    SettingsCard {
                        Picker("Microphone", selection: microphoneSelectionBinding) {
                            ForEach(appState.availableMicrophones, id: \.stableID) { microphone in
                                Text(microphone.displayName).tag(Optional(microphone.stableID))
                            }
                        }
                    }
                    SettingsCard {
                        Toggle("Launch at login", isOn: Binding(
                            get: { appState.isLaunchAtLoginEnabled },
                            set: { appState.setLaunchAtLogin(enabled: $0) }
                        ))
                    }

                    HStack {
                        Spacer()

                        Button(action: appState.reopenSetupFlow) {
                            Label("Redo Setup", systemImage: "gearshape")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(SettingsSubtleGhostButtonStyle())

                        Button(action: appState.openTranscriptionsFolder) {
                            Label("Debug Transcriptions", systemImage: "folder")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(SettingsSubtleGhostButtonStyle())
                    }
                }
                .padding(24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
        case .fn:
            return "Default. Simplest hold-to-talk option."
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
    case fn
    case rightCommand
    case rightOption
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
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
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title, title.isEmpty == false {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
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
                .background(Circle().fill(Color.red.opacity(0.9)))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                ScrollView {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 120)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Copy", action: copyMessage)
                    .buttonStyle(SettingsReflectiveButtonStyle())

                Button("Dismiss", action: dismiss)
                    .buttonStyle(SettingsReflectiveButtonStyle())
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.18),
                            Color.red.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.red.opacity(0.28), lineWidth: 1)
                )
        )
    }

    private func copyMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message, forType: .string)
    }
}

struct SettingsHeaderView: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.7))
            .frame(height: 1)
    }
}

struct SetupFlowCard: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Lets get you setup")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 4) {
                SetupPermissionRow(
                    icon: "mic.fill",
                    status: appState.permissionState.microphone,
                    primaryAction: { Task { await appState.requestMicrophonePermission() } },
                    secondaryAction: { appState.openAccessibilitySettings() },
                    primaryTitle: "Request Microphone",
                    secondaryTitle: "Go to System Settings"
                )

                SetupPermissionRow(
                    icon: "figure.wave.circle.fill",
                    status: appState.permissionState.accessibility,
                    primaryAction: { appState.requestAccessibilityPermission() },
                    secondaryAction: { appState.openAccessibilitySettings() },
                    primaryTitle: "Prompt Accessibility",
                    secondaryTitle: "Go to System Settings"
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("These will be installed via Homebrew")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    SetupInstallRow(
                        icon: "waveform",
                        state: appState.recorderSetupState,
                        primaryTitle: "Install SoX",
                        primaryAction: { appState.downloadRecorderSetup() },
                        secondaryTitle: "Reveal",
                        secondaryAction: { appState.revealRecorderFiles() }
                    )

                SetupInstallRow(
                    icon: "waveform.badge.magnifyingglass",
                    state: appState.whisperSetupState,
                    primaryTitle: "Download Whisper Model (1.5 GB)",
                    primaryAction: { appState.downloadWhisperSetup() },
                    secondaryTitle: "Reveal",
                    secondaryAction: { appState.revealWhisperFiles() }
                )
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: backgroundGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }

    private var backgroundGradient: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.06, green: 0.12, blue: 0.21),
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .windowBackgroundColor),
            ]
        }

        return [
            Color(red: 0.89, green: 0.94, blue: 1.00),
            Color.white,
            Color(red: 0.97, green: 0.98, blue: 1.00)
        ]
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.92)
    }
}

struct SettingsReflectiveButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(labelColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(primaryStrokeColor, lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(secondaryStrokeColor, lineWidth: 0.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }

    private var labelColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.94) : Color.black.opacity(0.78)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(isPressed ? 0.12 : 0.09)
        }

        return Color.white.opacity(isPressed ? 0.96 : 1.0)
    }

    private var primaryStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.95)
    }

    private var secondaryStrokeColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.30) : Color.black.opacity(0.05)
    }
}

struct SettingsSubtleGhostButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(labelColor)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(primaryStrokeColor, lineWidth: 1)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(secondaryStrokeColor, lineWidth: 0.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.84 : 1)
    }

    private var labelColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.82) : Color.secondary
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(isPressed ? 0.04 : 0.0)
        }

        return Color.white.opacity(isPressed ? 0.94 : 0.98)
    }

    private var primaryStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.92)
    }

    private var secondaryStrokeColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.black.opacity(0.05)
    }
}

struct SettingsPrimaryBlueButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }

    private func fillColor(isPressed: Bool) -> Color {
        let base = colorScheme == .dark
            ? Color(red: 0.28, green: 0.58, blue: 1.00)
            : Color(red: 0.23, green: 0.53, blue: 0.98)
        return base.opacity(isPressed ? 0.9 : 1)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.35)
    }
}

struct SetupPermissionRow: View {
    let icon: String
    let status: PermissionAuthorization
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let primaryTitle: String
    let secondaryTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Button(primaryTitle, systemImage: icon, action: primaryAction)
                    .buttonStyle(SettingsPrimaryBlueButtonStyle())
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(SettingsReflectiveButtonStyle())
                Spacer()
                PermissionStatusBadge(status: status)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SetupInstallRow: View {
    let icon: String
    let state: InstallProgressState
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String
    let secondaryAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(primaryTitle, systemImage: icon, action: primaryAction)
                .buttonStyle(SettingsReflectiveButtonStyle())
                .disabled(isWorking)
            Button(secondaryTitle, action: secondaryAction)
                .buttonStyle(SettingsReflectiveButtonStyle())

            Spacer()
            InstallStatusBadge(state: state)
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
        case .working(let message, _), .success(let message), .failure(let message):
            return message
        }
    }

}

struct PermissionStatusBadge: View {
    let status: PermissionAuthorization

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
    }

    private var title: String {
        switch status {
        case .granted:
            return "Granted"
        case .denied:
            return "Needs Access"
        case .notDetermined:
            return "Pending"
        }
    }

    private var icon: String {
        switch status {
        case .granted:
            return "checkmark"
        case .denied:
            return "exclamationmark"
        case .notDetermined:
            return "clock"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .granted:
            return Color.green.opacity(0.16)
        case .denied:
            return Color.red.opacity(0.12)
        case .notDetermined:
            return Color.black.opacity(0.08)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .granted:
            return Color.green.opacity(0.82)
        case .denied:
            return Color.red.opacity(0.82)
        case .notDetermined:
            return Color.black.opacity(0.65)
        }
    }
}

struct InstallStatusBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let state: InstallProgressState

    var body: some View {
        HStack(spacing: 8) {
            if isWorking {
                if let progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(foregroundColor)
                        .frame(width: 36)
                        .scaleEffect(x: 1, y: 0.7, anchor: .center)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.mini)
                        .tint(foregroundColor)
                }
            } else {
                Image(systemName: icon)
            }

            Text(title)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundColor)
        )
    }

    private var title: String {
        switch state {
        case .idle:
            return "Not Installed"
        case .working(let message, _):
            return message
        case .success:
            return "Ready"
        case .failure:
            return "Failed"
        }
    }

    private var progress: Double? {
        state.progress
    }

    private var icon: String {
        switch state {
        case .idle:
            return "arrow.down.circle"
        case .working:
            return "ellipsis"
        case .success:
            return "checkmark"
        case .failure:
            return "exclamationmark"
        }
    }

    private var isWorking: Bool {
        if case .working = state {
            return true
        }
        return false
    }

    private var backgroundColor: Color {
        switch state {
        case .success:
            return Color.green.opacity(0.16)
        case .failure:
            return Color.red.opacity(0.12)
        case .working:
            return Color.blue.opacity(0.12)
        case .idle:
            if colorScheme == .dark {
                return Color.white.opacity(0.07)
            }
            return Color.black.opacity(0.07)
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .success:
            return Color.green.opacity(0.82)
        case .failure:
            return Color.red.opacity(0.82)
        case .working:
            return Color.blue.opacity(0.82)
        case .idle:
            if colorScheme == .dark {
                return Color.white.opacity(0.65)
            }
            return Color.black.opacity(0.65)
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
