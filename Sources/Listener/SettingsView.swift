import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Shortcut") {
                Picker("Trigger", selection: shortcutTriggerBinding) {
                    ForEach(ShortcutSpec.TriggerKey.allCases) { trigger in
                        Text(triggerLabel(trigger)).tag(trigger)
                    }
                }

                if appState.preferences.shortcut.triggerKey == .customCharacter {
                    TextField("Custom key", text: customCharacterBinding)
                }

                ModifierTogglesView(shortcut: appState.preferences.shortcut) { updated in
                    appState.updateShortcut(updated)
                }
            }

            Section("Whisper") {
                Picker("Model", selection: modelBinding) {
                    ForEach(WhisperModelSelection.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                TextField("whisper-cli path", text: whisperPathBinding)
                    .textFieldStyle(.roundedBorder)
                TextField("Model file path", text: modelPathBinding)
                    .textFieldStyle(.roundedBorder)

                Stepper(
                    "Auto-unload after \(Int(appState.preferences.workerIdleTimeout))s",
                    value: idleTimeoutBinding,
                    in: 15...600,
                    step: 15
                )
            }

            Section("Insertion") {
                Picker("Fallback policy", selection: fallbackBinding) {
                    ForEach(TextInsertionFallbackPolicy.allCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
            }

            Section("Permissions") {
                HStack {
                    Text("Microphone")
                    Spacer()
                    Text(appState.permissionState.microphone.rawValue)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Accessibility")
                    Spacer()
                    Text(appState.permissionState.accessibility.rawValue)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Input Monitoring")
                    Spacer()
                    Text(appState.permissionState.inputMonitoring.rawValue)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Request Microphone") {
                        Task { await appState.requestMicrophonePermission() }
                    }
                    Button("Open Accessibility") {
                        appState.openAccessibilitySettings()
                    }
                    Button("Open Input Monitoring") {
                        appState.openInputMonitoringSettings()
                    }
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: Binding(
                    get: { appState.isLaunchAtLoginEnabled },
                    set: { appState.setLaunchAtLogin(enabled: $0) }
                ))
            }

            if let error = appState.lastErrorMessage {
                Section("Last Error") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var shortcutTriggerBinding: Binding<ShortcutSpec.TriggerKey> {
        Binding(
            get: { appState.preferences.shortcut.triggerKey },
            set: {
                var updated = appState.preferences.shortcut
                updated.triggerKey = $0
                if $0 != .customCharacter {
                    updated.customCharacter = nil
                }
                appState.updateShortcut(updated)
            }
        )
    }

    private var customCharacterBinding: Binding<String> {
        Binding(
            get: { appState.preferences.shortcut.customCharacter ?? "" },
            set: {
                var updated = appState.preferences.shortcut
                updated.customCharacter = String($0.prefix(1))
                appState.updateShortcut(updated)
            }
        )
    }

    private var modelBinding: Binding<WhisperModelSelection> {
        Binding(
            get: { appState.preferences.modelSelection },
            set: {
                appState.updateModelSelection($0)
                if appState.preferences.modelPath.hasSuffix(".bin") == false {
                    appState.updateModelPath("~/Library/Application Support/Listener/\($0.suggestedFilename)")
                }
            }
        )
    }

    private var whisperPathBinding: Binding<String> {
        Binding(
            get: { appState.preferences.whisperBinaryPath },
            set: { appState.updateWhisperBinaryPath($0) }
        )
    }

    private var modelPathBinding: Binding<String> {
        Binding(
            get: { appState.preferences.modelPath },
            set: { appState.updateModelPath($0) }
        )
    }

    private var fallbackBinding: Binding<TextInsertionFallbackPolicy> {
        Binding(
            get: { appState.preferences.fallbackPolicy },
            set: { appState.updateFallbackPolicy($0) }
        )
    }

    private var idleTimeoutBinding: Binding<Double> {
        Binding(
            get: { appState.preferences.workerIdleTimeout },
            set: { appState.updateIdleTimeout($0) }
        )
    }

    private func triggerLabel(_ trigger: ShortcutSpec.TriggerKey) -> String {
        switch trigger {
        case .fn:
            return "Fn"
        case .rightCommand:
            return "Right Command"
        case .rightOption:
            return "Right Option"
        case .space:
            return "Space"
        case .grave:
            return "Grave (`)"
        case .customCharacter:
            return "Custom Character"
        }
    }
}

struct ModifierTogglesView: View {
    let shortcut: ShortcutSpec
    let onUpdate: (ShortcutSpec) -> Void

    var body: some View {
        HStack {
            modifierToggle("Control", flag: .control)
            modifierToggle("Option", flag: .option)
            modifierToggle("Shift", flag: .shift)
            modifierToggle("Command", flag: .command)
        }
    }

    private func modifierToggle(_ title: String, flag: EventModifiers) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { shortcut.modifiers.contains(flag) },
                set: { enabled in
                    var updated = shortcut
                    if enabled {
                        updated.modifiers.insert(flag)
                    } else {
                        updated.modifiers.remove(flag)
                    }
                    onUpdate(updated)
                }
            )
        )
        .toggleStyle(.switch)
    }
}
