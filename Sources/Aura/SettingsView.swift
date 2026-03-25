import AppKit
import Carbon.HIToolbox
import SwiftUI

enum SettingsDestination: String, CaseIterable, Identifiable {
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .history:
            return "Recent dictation history"
        case .settings:
            return "App configuration"
        }
    }

    var icon: String {
        switch self {
        case .history:
            return "house"
        case .settings:
            return "gearshape"
        }
    }
}

struct HistoryDaySection: Identifiable, Equatable {
    let day: Date
    let title: String
    let items: [VoiceTextHistoryItem]

    var id: Date { day }
}

enum HistorySectionBuilder {
    static func makeSections(
        from items: [VoiceTextHistoryItem],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> [HistoryDaySection] {
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.createdAt)
        }

        return grouped
            .map { day, items in
                HistoryDaySection(
                    day: day,
                    title: title(for: day, now: now, calendar: calendar),
                    items: items.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.day > $1.day }
    }

    private static func title(for day: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(day, inSameDayAs: now) {
            return "Today"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }

        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedDestination: SettingsDestination = .settings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(
                selectedDestination: $selectedDestination,
                theme: theme
            )
            .frame(width: 228)

            Group {
                switch selectedDestination {
                case .history:
                    SettingsHomeView(theme: theme)
                        .environmentObject(appState)
                case .settings:
                    SettingsDetailView(theme: theme)
                        .environmentObject(appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            selectedDestination = appState.isSetupComplete ? .history : .settings
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appState.preferences.appearance {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private var theme: AuraTheme {
        appState.preferences.auraColor.theme
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedDestination: SettingsDestination
    let theme: AuraTheme

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(SettingsDestination.allCases) { destination in
                    SidebarDestinationButton(
                        destination: destination,
                        isSelected: selectedDestination == destination,
                        theme: theme
                    ) {
                        selectedDestination = destination
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(sidebarBackground)
    }

    private var sidebarBackground: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.05)
        }

        return Color.black.opacity(0.035)
    }

}

private struct SidebarDestinationButton: View {
    let destination: SettingsDestination
    let isSelected: Bool
    let theme: AuraTheme
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: destination.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.title)
                        .font(.system(size: 14, weight: .semibold))
                }

                Spacer()
            }
            .foregroundStyle(isSelected ? selectedTextColor : defaultTextColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(activeBackground)
    }

    private var selectedTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.94) : .black.opacity(0.9)
    }

    private var defaultTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.88) : .black.opacity(0.78)
    }

    private var activeBackground: Color {
        guard isSelected else { return .clear }

        if colorScheme == .dark {
            return Color.white.opacity(0.11)
        }

        return Color.black.opacity(0.09)
    }
}

private struct SettingsHomeView: View {
    @EnvironmentObject private var appState: AppState

    let theme: AuraTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VoiceResponseHistoryHomeCard(
                    items: appState.preferences.voiceTextHistory,
                    theme: theme,
                    onDelete: { appState.removeVoiceTextHistoryItem(id: $0.id) }
                )

                HStack {
                    Spacer()

                    Button(action: appState.clearVoiceTextHistory) {
                        Label("Clear History", systemImage: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(SettingsSubtleGhostButtonStyle(theme: theme))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
        }
        .background(alignment: .topLeading) {
            historyBackground
        }
    }

    private var historyBackground: some View {
        RadialGradient(
            colors: [
                theme.accentStrong.color.opacity(colorScheme == .dark ? 0.20 : 0.16),
                theme.accentStrong.color.opacity(colorScheme == .dark ? 0.08 : 0.05),
                Color.clear
            ],
            center: .topLeading,
            startRadius: 0,
            endRadius: 460
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct SettingsDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isCapturingShortcut = false

    let theme: AuraTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let error = appState.lastErrorMessage, !error.isEmpty {
                    SettingsWarningCard(
                        title: "Warning",
                        message: error,
                        theme: theme,
                        dismiss: { appState.clearError() }
                    )
                }

                SetupFlowCard(appState: appState, theme: theme)

                SettingsCard(theme: theme) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Shortcut", selection: presetShortcutBinding) {
                                ForEach(ShortcutPreset.allCases) { preset in
                                    Text(preset.label).tag(preset)
                                }
                            }

                            if appState.preferences.shortcut.triggerKey == .customShortcut || isCapturingShortcut {
                                HStack {
                                    Text("Current")
                                    Spacer()
                                    Text(appState.preferences.shortcut.displayName)
                                        .foregroundStyle(.secondary)
                                }

                                ShortcutCaptureButton(
                                    isCapturing: $isCapturingShortcut,
                                    currentTitle: appState.preferences.shortcut.displayName,
                                    theme: theme
                                ) { shortcut in
                                    appState.updateShortcut(shortcut)
                                    isCapturingShortcut = false
                                }
                            }
                        }
                    }
                }

                SettingsCard(theme: theme) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Microphone", selection: microphoneSelectionBinding) {
                            Text(systemDefaultMicrophoneLabel).tag(Optional<UInt32>.none)

                            ForEach(appState.availableMicrophones, id: \.stableID) { microphone in
                                Text(microphone.displayName).tag(Optional(microphone.stableID))
                            }
                        }
                    }
                }

                SettingsCard(theme: theme) {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("Color Scheme", selection: auraColorBinding) {
                            ForEach(AuraColorOption.allCases) { option in
                                AuraColorOptionLabel(option: option).tag(option)
                            }
                        }

                        Picker("Appearance", selection: appearanceBinding) {
                            ForEach(AppAppearanceOption.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }

                        Picker("Orb Appearance", selection: orbAppearanceBinding) {
                            ForEach(OrbAppearanceOption.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    }
                }

                SettingsCard(theme: theme) {
                    VStack(alignment: .leading, spacing: 18) {
                        Toggle("Launch at login", isOn: Binding(
                            get: { appState.isLaunchAtLoginEnabled },
                            set: { appState.setLaunchAtLogin(enabled: $0) }
                        ))
                    }
                }

                HStack {
                    Spacer()

                    Button(action: appState.openTranscriptionsFolder) {
                        Label("Debug Transcriptions", systemImage: "folder")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(SettingsSubtleGhostButtonStyle(theme: theme))
                }
            }
            .padding(28)
        }
    }

    private var microphoneSelectionBinding: Binding<UInt32?> {
        Binding(
            get: { appState.preferences.selectedMicrophoneID },
            set: { appState.updateSelectedMicrophoneID($0) }
        )
    }

    private var systemDefaultMicrophoneLabel: String {
        guard let microphone = appState.availableMicrophones.first(where: { $0.isDefault }) else {
            return "System Default"
        }

        return "System Default (\(microphone.displayName))"
    }

    private var auraColorBinding: Binding<AuraColorOption> {
        Binding(
            get: { appState.preferences.auraColor },
            set: { appState.preferences.auraColor = $0 }
        )
    }

    private var appearanceBinding: Binding<AppAppearanceOption> {
        Binding(
            get: { appState.preferences.appearance },
            set: { appState.preferences.appearance = $0 }
        )
    }

    private var orbAppearanceBinding: Binding<OrbAppearanceOption> {
        Binding(
            get: { appState.preferences.orbAppearance },
            set: { appState.preferences.orbAppearance = $0 }
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

}

struct VoiceResponseHistoryHomeCard: View {
    let items: [VoiceTextHistoryItem]
    let theme: AuraTheme
    let onDelete: (VoiceTextHistoryItem) -> Void

    private let calendar = Calendar.autoupdatingCurrent
    @State private var copiedFeedbackText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Spacer()

                HistoryCopyFeedbackBanner(
                    isVisible: copiedFeedbackText != nil,
                    theme: theme
                )
            }
            .padding(.top, 2)

            if items.isEmpty {
                SettingsCard(theme: theme) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("History")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))

                        Text("Your responses will appear here after you finish a dictation.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.system(size: section.title == "Today" ? 24 : 18, weight: .semibold, design: .rounded))
                            .padding(.leading, 2)
                            .padding(.bottom, section.title == "Today" ? 4 : 0)

                        VoiceResponseHistoryDaySectionCard(
                            section: section,
                            theme: theme,
                            onDelete: onDelete,
                            onCopy: handleCopy
                        )
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: copiedFeedbackText)
    }

    private var sections: [HistoryDaySection] {
        HistorySectionBuilder.makeSections(from: items, calendar: calendar)
    }

    private func handleCopy(_ item: VoiceTextHistoryItem) {
        copiedFeedbackText = item.text

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            if copiedFeedbackText == item.text {
                copiedFeedbackText = nil
            }
        }
    }
}

private struct VoiceResponseHistoryDaySectionCard: View {
    let section: HistoryDaySection
    let theme: AuraTheme
    let onDelete: (VoiceTextHistoryItem) -> Void
    let onCopy: (VoiceTextHistoryItem) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SettingsCard(theme: theme, contentPadding: 0) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 0) {
                        Text("Time")
                            .frame(width: 72, alignment: .leading)
                        Spacer()
                            .frame(width: 16)
                        Text("Transcript")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 0)
                        Color.clear.frame(width: 24, height: 1)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 18)
                    }

                    VoiceResponseHistoryTableRow(
                        item: item,
                        theme: theme,
                        onDelete: { onDelete(item) },
                        onCopy: { onCopy(item) }
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

private struct VoiceResponseHistoryTableRow: View {
    let item: VoiceTextHistoryItem
    let theme: AuraTheme
    let onDelete: () -> Void
    let onCopy: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isMenuPresented = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: copyText) {
                HStack(alignment: .top, spacing: 16) {
                    Text(timestamp)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)

                    Text(item.text)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                isMenuPresented.toggle()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(menuIconColor)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isMenuPresented, attachmentAnchor: .point(.topTrailing)) {
                HistoryRowActionPopover(
                    theme: theme,
                    onCopy: {
                        isMenuPresented = false
                        copyText()
                    },
                    onDelete: {
                        isMenuPresented = false
                        onDelete()
                    }
                )
            }
        }
    }

    private var timestamp: String {
        item.createdAt.formatted(date: .omitted, time: .shortened)
    }

    private var menuIconColor: Color {
        colorScheme == .dark ? .white.opacity(0.72) : .black.opacity(0.56)
    }

    private func rowBackground(isHovered: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.historyRowFill(for: colorScheme))
    }

    private func copyText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        onCopy()
    }
}

private struct HistoryRowActionPopover: View {
    let theme: AuraTheme
    let onCopy: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onCopy) {
                historyActionLabel(title: "Copy", systemImage: "doc.on.doc", tint: primaryTextColor)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                historyActionLabel(title: "Delete", systemImage: "trash", tint: deleteColor)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .frame(width: 144, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.cardFill(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.cardBorder(for: colorScheme), lineWidth: 1)
                )
        )
        .padding(4)
    }

    private func historyActionLabel(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 14)

            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.historyRowFill(for: colorScheme))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.9) : theme.accentText.color
    }

    private var deleteColor: Color {
        theme.error.foreground.color
    }
}

private struct HistoryCopyFeedbackBanner: View {
    let isVisible: Bool
    let theme: AuraTheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .foregroundStyle(theme.success.foreground.color)

            Text("Copied")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.success.foreground.color)
                .lineLimit(1)
        }
        .frame(height: 40)
        .opacity(isVisible ? 1 : 0)
        .frame(width: 110, alignment: .trailing)
    }
}

private struct AuraColorOptionLabel: View {
    let option: AuraColorOption

    var body: some View {
        Label {
            Text(option.label)
        } icon: {
            Circle()
                .fill(option.theme.accentStrong.color)
                .frame(width: 10, height: 10)
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
    @Environment(\.colorScheme) private var colorScheme

    let theme: AuraTheme
    let title: String?
    let contentPadding: CGFloat
    @ViewBuilder let content: Content

    init(theme: AuraTheme, title: String? = nil, contentPadding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.title = title
        self.contentPadding = contentPadding
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
        .padding(contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.cardFill(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.cardTint(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(theme.cardBorder(for: colorScheme), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct SettingsWarningCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let message: String
    let theme: AuraTheme
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .padding(10)
                .background(Circle().fill(theme.warning.border.color))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.warning.foreground.color)

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
                    .buttonStyle(SettingsReflectiveButtonStyle(theme: theme))

                Button("Dismiss", action: dismiss)
                    .buttonStyle(SettingsReflectiveButtonStyle(theme: theme))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.warningCardBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(theme.warningCardBorder(for: colorScheme), lineWidth: 1)
                )
        )
    }

    private func copyMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message, forType: .string)
    }
}

struct SetupFlowCard: View {
    @ObservedObject var appState: AppState
    let theme: AuraTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                SetupPermissionRow(
                    icon: "mic.fill",
                    status: appState.permissionState.microphone,
                    primaryAction: { Task { await appState.requestMicrophonePermission() } },
                    secondaryAction: { appState.openAccessibilitySettings() },
                    primaryTitle: "Request Microphone",
                    secondaryTitle: "Go to System Settings",
                    theme: theme
                )

                SetupPermissionRow(
                    icon: "figure.wave.circle.fill",
                    status: appState.permissionState.accessibility,
                    primaryAction: { appState.requestAccessibilityPermission() },
                    secondaryAction: { appState.openAccessibilitySettings() },
                    primaryTitle: "Prompt Accessibility",
                    secondaryTitle: "Go to System Settings",
                    theme: theme
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Aura bundles whisper.cpp directly and keeps the model in the app cache.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    SetupInstallRow(
                        icon: "waveform.badge.magnifyingglass",
                        state: appState.whisperSetupState,
                        primaryTitle: "Install Medium English (1.5 GB)",
                        primaryAction: { appState.downloadWhisperSetup() },
                        secondaryTitle: "Reveal",
                        secondaryAction: { appState.revealWhisperFiles() },
                        theme: theme
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
                theme.overlay.baseOuter.color.opacity(0.20),
                ThemeColor(red: 0.10, green: 0.10, blue: 0.10, opacity: 0.96).color,
                ThemeColor(red: 0.08, green: 0.08, blue: 0.08, opacity: 0.98).color
            ]
        }

        return theme.setupGradient(for: colorScheme)
    }

    private var borderColor: Color {
        if colorScheme == .dark {
            return theme.setupBorder(for: colorScheme).opacity(0.74)
        }

        return theme.setupBorder(for: colorScheme)
    }
}

struct SettingsReflectiveButtonStyle: ButtonStyle {
    let theme: AuraTheme

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
        theme.reflectiveButtonLabel(for: colorScheme)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        theme.reflectiveButtonBackground(isPressed: isPressed, colorScheme: colorScheme)
    }

    private var primaryStrokeColor: Color {
        theme.reflectiveButtonPrimaryStroke(for: colorScheme)
    }

    private var secondaryStrokeColor: Color {
        theme.reflectiveButtonSecondaryStroke(for: colorScheme)
    }
}

struct SettingsSubtleGhostButtonStyle: ButtonStyle {
    let theme: AuraTheme

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
        theme.ghostButtonLabel(for: colorScheme)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        theme.ghostButtonBackground(isPressed: isPressed, colorScheme: colorScheme)
    }

    private var primaryStrokeColor: Color {
        theme.ghostButtonPrimaryStroke(for: colorScheme)
    }

    private var secondaryStrokeColor: Color {
        theme.ghostButtonSecondaryStroke(for: colorScheme)
    }
}

struct SettingsPrimaryButtonStyle: ButtonStyle {
    let theme: AuraTheme

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
        theme.primaryButtonFill(isPressed: isPressed, colorScheme: colorScheme)
    }

    private var borderColor: Color {
        theme.primaryButtonBorder(for: colorScheme)
    }
}

struct SetupPermissionRow: View {
    let icon: String
    let status: PermissionAuthorization
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let primaryTitle: String
    let secondaryTitle: String
    let theme: AuraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Button(primaryTitle, systemImage: icon, action: primaryAction)
                    .buttonStyle(SettingsPrimaryButtonStyle(theme: theme))
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(SettingsReflectiveButtonStyle(theme: theme))
                Spacer()
                PermissionStatusBadge(status: status, theme: theme)
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
    let theme: AuraTheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(primaryTitle, systemImage: icon, action: primaryAction)
                .buttonStyle(SettingsReflectiveButtonStyle(theme: theme))
                .disabled(isWorking)
            Button(secondaryTitle, action: secondaryAction)
                .buttonStyle(SettingsReflectiveButtonStyle(theme: theme))

            Spacer()
            InstallStatusBadge(state: state, theme: theme)
        }
        .padding(.vertical, 4)
    }

    private var isWorking: Bool {
        if case .working = state { return true }
        return false
    }
}

struct PermissionStatusBadge: View {
    let status: PermissionAuthorization
    let theme: AuraTheme

    @Environment(\.colorScheme) private var colorScheme

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
        if colorScheme == .dark {
            return theme.badgePalette(for: status).foreground.color.opacity(0.18)
        }

        return theme.badgePalette(for: status).background.color
    }

    private var foregroundColor: Color {
        if colorScheme == .dark {
            return theme.badgePalette(for: status).background.color
        }

        return theme.badgePalette(for: status).foreground.color
    }
}

struct InstallStatusBadge: View {
    let state: InstallProgressState
    let theme: AuraTheme

    @Environment(\.colorScheme) private var colorScheme

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
        if colorScheme == .dark {
            return theme.badgePalette(for: state).foreground.color.opacity(0.18)
        }

        return theme.badgePalette(for: state).background.color
    }

    private var foregroundColor: Color {
        if colorScheme == .dark {
            return theme.badgePalette(for: state).background.color
        }

        return theme.badgePalette(for: state).foreground.color
    }
}

struct ShortcutCaptureButton: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let currentTitle: String
    let theme: AuraTheme
    let onCapture: (ShortcutSpec) -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "Record Custom Shortcut", target: context.coordinator, action: #selector(Coordinator.toggleCapture))
        button.bezelStyle = .rounded
        context.coordinator.button = button
        applyTheme(to: button)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
        button.title = isCapturing ? "Press a shortcut…" : "Change Custom Shortcut"
        applyTheme(to: button)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func applyTheme(to button: NSButton) {
        button.bezelColor = NSColor(theme.accentStrong.color)
        button.contentTintColor = .white
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
