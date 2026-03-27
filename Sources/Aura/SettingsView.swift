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
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDestination: SettingsDestination = .settings

    var body: some View {
        ZStack {
            settingsContent
                .blur(radius: setupOverlayIsVisible ? 4 : 0)
                .disabled(setupOverlayIsVisible)

            if setupOverlayIsVisible {
                SetupFlowOverlay(
                    appState: appState,
                    theme: theme,
                    canDismiss: appState.hasCompletedSetup,
                    onDismiss: { appState.dismissSetupOverlay() }
                )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(preferredColorScheme)
        .animation(.easeInOut(duration: 0.22), value: setupOverlayIsVisible)
        .onAppear {
            selectedDestination = appState.requiresSetup ? .settings : .history
        }
        .onChange(of: appState.requiresSetup) { requiresSetup in
            if requiresSetup {
                selectedDestination = .settings
            }
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

    private var setupOverlayIsVisible: Bool {
        appState.shouldShowSetupOverlay
    }

    private var settingsContent: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                sidebarBackground
                    .ignoresSafeArea(edges: .top)

                SettingsSidebar(
                    selectedDestination: $selectedDestination,
                    theme: theme
                )

                Rectangle()
                    .fill(theme.divider(for: colorScheme))
                    .frame(width: 1)
                    .ignoresSafeArea(edges: .top)
            }
            .frame(width: 228)
            .frame(maxHeight: .infinity)

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
            .background(detailBackground.ignoresSafeArea())
        }
    }

    private var sidebarBackground: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)

            LinearGradient(
                colors: [
                    theme.accentSoft.color.opacity(colorScheme == .dark ? 0.09 : 0.18),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var detailBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            RadialGradient(
                colors: [
                    theme.accentSoft.color.opacity(colorScheme == .dark ? 0.07 : 0.16),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 420
            )
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedDestination: SettingsDestination
    let theme: AuraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSidebarHeader(theme: theme)

            VStack(alignment: .leading, spacing: 8) {
                Text("Pages")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

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
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SettingsSidebarHeader: View {
    let theme: AuraTheme

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.accentStrong.color,
                            theme.accentMuted.color
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                }
                .shadow(
                    color: theme.shadow.color.opacity(colorScheme == .dark ? 0.18 : 0.10),
                    radius: 10,
                    x: 0,
                    y: 5
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Aura")
                    .font(.system(size: 15, weight: .semibold))

                Text("Menu bar dictation")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: destination.icon)
                            .font(.system(size: 13, weight: .semibold))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.title)
                        .font(.system(size: 14, weight: .semibold))

                    Text(destination.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .foregroundStyle(isSelected ? selectedTextColor : defaultTextColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(activeBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(activeBorder, lineWidth: 1)
            )
    }

    private var selectedTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.94) : .black.opacity(0.9)
    }

    private var defaultTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.88) : .black.opacity(0.78)
    }

    private var activeBackground: Color {
        guard isSelected else { return .clear }

        return theme.accentStrong.color.opacity(colorScheme == .dark ? 0.18 : 0.10)
    }

    private var activeBorder: Color {
        guard isSelected else { return .clear }
        return theme.accentBorder.color.opacity(colorScheme == .dark ? 0.34 : 0.42)
    }

    private var iconBackground: Color {
        if isSelected {
            return theme.accentStrong.color.opacity(colorScheme == .dark ? 0.30 : 0.14)
        }

        return colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.045)
    }
}

private struct SettingsHomeView: View {
    @EnvironmentObject private var appState: AppState

    let theme: AuraTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsPageHeader(
                    title: "History",
                    subtitle: "Review recent dictation output and manage saved transcripts.",
                    detail: historySummary
                ) {
                    if appState.preferences.voiceTextHistory.isEmpty == false {
                        Button(action: appState.clearVoiceTextHistory) {
                            Label("Clear History", systemImage: "trash")
                        }
                        .buttonStyle(SettingsSubtleGhostButtonStyle(theme: theme))
                    }
                }

                VoiceResponseHistoryHomeCard(
                    items: appState.preferences.voiceTextHistory,
                    theme: theme,
                    onDelete: { appState.removeVoiceTextHistoryItem(id: $0.id) }
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
    }

    private var historySummary: String {
        let count = appState.preferences.voiceTextHistory.count
        switch count {
        case 0:
            return "No saved transcripts"
        case 1:
            return "1 saved transcript"
        default:
            return "\(count) saved transcripts"
        }
    }
}

private struct SettingsDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isCapturingShortcut = false

    let theme: AuraTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsPageHeader(
                    title: "Settings",
                    subtitle: "Adjust how Aura listens, looks, and behaves.",
                    detail: currentAppVersionDisplay()
                )

                if let error = appState.lastErrorMessage, !error.isEmpty {
                    SettingsWarningCard(
                        title: "Warning",
                        message: error,
                        theme: theme,
                        dismiss: { appState.clearError() }
                    )
                }

                SettingsSectionCard(
                    theme: theme,
                    systemImage: "keyboard",
                    title: "Shortcut",
                    description: "Choose how you trigger Aura before it starts listening."
                ) {
                    SettingsControlRow(
                        title: "Trigger",
                        description: "Pick the key you press and hold to start dictation."
                    ) {
                        Picker("Shortcut", selection: presetShortcutBinding) {
                            ForEach(ShortcutPreset.allCases) { preset in
                                Text(preset.label).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    if appState.preferences.shortcut.triggerKey == .customShortcut || isCapturingShortcut {
                        SettingsRowDivider()

                        SettingsControlRow(
                            title: "Custom Shortcut",
                            description: "Press Escape while recording if you want to cancel the capture."
                        ) {
                            VStack(alignment: .trailing, spacing: 10) {
                                SettingsValueBadge(text: appState.preferences.shortcut.displayName)

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

                SettingsSectionCard(
                    theme: theme,
                    systemImage: "mic",
                    title: "Audio Input",
                    description: "Select which microphone Aura should use when recording."
                ) {
                    SettingsControlRow(
                        title: "Microphone",
                        description: "System Default follows the input device currently chosen in macOS."
                    ) {
                        Picker("Microphone", selection: microphoneSelectionBinding) {
                            Text(systemDefaultMicrophoneLabel).tag(Optional<UInt32>.none)

                            ForEach(appState.availableMicrophones, id: \.stableID) { microphone in
                                Text(microphone.displayName).tag(Optional(microphone.stableID))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 260)
                    }
                }

                SettingsSectionCard(
                    theme: theme,
                    systemImage: "paintpalette",
                    title: "Appearance",
                    description: "Tune the accent color and window appearance Aura uses."
                ) {
                    SettingsControlRow(
                        title: "Aura Color",
                        description: "This changes the accent color used across the app and overlay."
                    ) {
                        Picker("Color Scheme", selection: auraColorBinding) {
                            ForEach(AuraColorOption.allCases) { option in
                                AuraColorOptionLabel(option: option).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    SettingsRowDivider()

                    SettingsControlRow(
                        title: "Window Appearance",
                        description: "Follow the system or force Aura to stay light or dark."
                    ) {
                        Picker("Appearance", selection: appearanceBinding) {
                            ForEach(AppAppearanceOption.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                }

                SettingsSectionCard(
                    theme: theme,
                    systemImage: "power",
                    title: "Startup & Tools",
                    description: "Control how Aura launches and reopen its support flows when needed."
                ) {
                    SettingsControlRow(
                        title: "Launch at Login",
                        description: "Open Aura automatically after you sign in to your Mac."
                    ) {
                        Toggle("Launch at login", isOn: Binding(
                            get: { appState.isLaunchAtLoginEnabled },
                            set: { appState.setLaunchAtLogin(enabled: $0) }
                        ))
                        .labelsHidden()
                    }

                    SettingsRowDivider()

                    SettingsControlRow(
                        title: "Setup Assistant",
                        description: "Revisit permissions and the model download flow from the beginning."
                    ) {
                        Button("Redo Setup", action: appState.presentSetupOverlay)
                            .buttonStyle(SettingsReflectiveButtonStyle(theme: theme))
                    }

                    SettingsRowDivider()

                    SettingsControlRow(
                        title: "Debug Transcriptions",
                        description: "Open the temporary folder Aura uses while processing recordings."
                    ) {
                        Button("Open Folder", action: appState.openTranscriptionsFolder)
                            .buttonStyle(SettingsReflectiveButtonStyle(theme: theme))
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
    }

    private var microphoneSelectionBinding: Binding<UInt32?> {
        Binding(
            get: { appState.effectiveSelectedMicrophoneID },
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

private struct SettingsPageHeader<Accessory: View>: View {
    let title: String
    let subtitle: String
    let detail: String?
    @ViewBuilder let accessory: Accessory

    init(
        title: String,
        subtitle: String,
        detail: String? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail, detail.isEmpty == false {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 16)

            accessory
        }
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let theme: AuraTheme
    let systemImage: String
    let title: String
    let description: String
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SettingsCard(theme: theme, contentPadding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 34, height: 34)
                        .overlay {
                            Image(systemName: systemImage)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(theme.accentStrong.color)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))

                        Text(description)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 14)

                Divider()
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }

    private var iconBackground: Color {
        theme.accentStrong.color.opacity(colorScheme == .dark ? 0.18 : 0.10)
    }
}

private struct SettingsControlRow<Control: View>: View {
    let title: String
    let description: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 18)

            control
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}

private struct SettingsRowDivider: View {
    var body: some View {
        Divider()
    }
}

private struct SettingsValueBadge: View {
    let text: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
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

private func currentAppVersionDisplay(bundle: Bundle = .main) -> String {
    let shortVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let buildNumber = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)

    if let shortVersion, shortVersion.isEmpty == false,
       let buildNumber, buildNumber.isEmpty == false,
       buildNumber != shortVersion {
        return "Version \(shortVersion) (\(buildNumber))"
    }

    if let shortVersion, shortVersion.isEmpty == false {
        return "Version \(shortVersion)"
    }

    if let buildNumber, buildNumber.isEmpty == false {
        return "Version \(buildNumber)"
    }

    return "Version unavailable"
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

private struct SetupFlowOverlay: View {
    @ObservedObject var appState: AppState
    let theme: AuraTheme
    let canDismiss: Bool
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            overlayBackground

            SetupFlowCard(
                appState: appState,
                theme: theme,
                canDismiss: canDismiss,
                onDismiss: onDismiss
            )
                .frame(maxWidth: 560)
                .shadow(
                    color: theme.shadow.color.opacity(colorScheme == .dark ? 0.30 : 0.18),
                    radius: 28,
                    x: 0,
                    y: 18
                )
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var overlayBackground: some View {
        ZStack {
            LinearGradient(
                colors: theme.setupGradient(for: colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? 0.92 : 0.96)

            RadialGradient(
                colors: [
                    theme.accentStrong.color.opacity(colorScheme == .dark ? 0.28 : 0.18),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 18,
                endRadius: 520
            )

            Rectangle()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06))
        }
        .ignoresSafeArea()
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
    let canDismiss: Bool
    let onDismiss: () -> Void

    var body: some View {
        SettingsCard(theme: theme, contentPadding: 24) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Let's get you set up")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))

                    Text("We needs permissions and some dependencies before we can start.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 14) {
                    SetupPermissionRow(
                        icon: "mic.fill",
                        title: "Microphone Access",
                        message: "Allows Aura to capture audio directly from your selected microphone.",
                        status: appState.permissionState.microphone,
                        primaryAction: { Task { await appState.requestMicrophonePermission() } },
                        secondaryAction: { appState.openMicrophoneSettings() },
                        primaryTitle: "Request Access",
                        secondaryTitle: "Open System Settings",
                        theme: theme
                    )

                    SetupPermissionRow(
                        icon: "figure.wave.circle.fill",
                        title: "Accessibility Access",
                        message: "Lets Aura insert the transcript into the app where your cursor is currently focused.",
                        status: appState.permissionState.accessibility,
                        primaryAction: { appState.requestAccessibilityPermission() },
                        secondaryAction: { appState.openAccessibilitySettings() },
                        primaryTitle: "Prompt for Access",
                        secondaryTitle: "Open System Settings",
                        theme: theme
                    )

                    SetupModelDownloadSection(
                        state: appState.whisperModelSetupState,
                        retryAction: appState.retryWhisperModelDownload,
                        theme: theme
                    )
                }

                HStack(spacing: 8) {
                    Spacer()
                    if canDismiss {
                        Button("Continue", action: onDismiss)
                            .buttonStyle(SettingsReflectiveButtonStyle(theme: theme))
                    }
                }
            }
        }
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
    let title: String
    let message: String
    let status: PermissionAuthorization
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let primaryTitle: String
    let secondaryTitle: String
    let theme: AuraTheme

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(theme.accentStrong.color.opacity(colorScheme == .dark ? 0.20 : 0.12))

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.accentStrong.color)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))

                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                PermissionStatusBadge(status: status, theme: theme)
            }

            if status != .granted {
                HStack(spacing: 10) {
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(SettingsPrimaryButtonStyle(theme: theme))

                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(SettingsReflectiveButtonStyle(theme: theme))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.historyRowFill(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.historyRowBorder(for: colorScheme), lineWidth: 1)
                )
        )
    }
}

struct SetupModelDownloadSection: View {
    let state: WhisperModelSetupState
    let retryAction: () -> Void
    let theme: AuraTheme

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    switch state {
                    case .checking:
                        modelMessage("Checking for an existing model...")
                    case .preparing(let stage):
                        modelMessage(stage)
                    case .downloading(_, let stage):
                        modelMessage(stage)
                    case .installed:
                        modelMessage("Dependencies have been downloaded")
                    case .failed(let message):
                        VStack(alignment: .leading, spacing: 6) {
                            modelErrorMessage(message)

                            Button("Retry Download", action: retryAction)
                                .buttonStyle(SettingsPrimaryButtonStyle(theme: theme))
                        }
                    }

                    Spacer()

                    SetupModelStatusBadge(state: state, theme: theme)
                }

                switch state {
                case .checking:
                    ProgressView(value: 0, total: 1)
                        .tint(theme.accentStrong.color)
                case .preparing:
                    ProgressView(value: 0, total: 1)
                        .tint(theme.accentStrong.color)
                case .downloading(let progress, _):
                    ProgressView(value: progress, total: 1)
                        .tint(theme.accentStrong.color)
                case .installed:
                    ProgressView(value: 1, total: 1)
                        .tint(theme.accentStrong.color)
                case .failed:
                    ProgressView(value: 0, total: 1)
                        .tint(theme.accentStrong.color)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(modelCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(modelCardBorder, lineWidth: 1)
                )
        )
    }

    private func progressLabel(for progress: Double) -> String {
        let percent = Int((min(max(progress, 0), 1) * 100).rounded())
        return "Downloading \(percent)%"
    }

    private func modelMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(messageColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func modelErrorMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(theme.error.foreground.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var modelCardFill: Color {
        theme.historyRowFill(for: colorScheme)
    }

    private var modelCardBorder: Color {
        theme.historyRowBorder(for: colorScheme)
    }

    private var messageColor: Color {
        .primary
    }
}

struct SetupModelStatusBadge: View {
    let state: WhisperModelSetupState
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
        switch state {
        case .checking:
            return "Checking"
        case .preparing:
            return "Preparing"
        case .downloading(let progress, _):
            return downloadProgressLabel(for: progress)
        case .installed:
            return "Complete"
        case .failed:
            return "Error"
        }
    }

    private var icon: String {
        switch state {
        case .checking:
            return "clock"
        case .preparing:
            return "shippingbox"
        case .downloading:
            return "arrow.down"
        case .installed:
            return "checkmark"
        case .failed:
            return "exclamationmark"
        }
    }

    private var palette: AuraTheme.StatusPalette {
        switch state {
        case .installed:
            return theme.success
        case .failed:
            return theme.error
        case .checking, .preparing, .downloading:
            return theme.neutral
        }
    }

    private var backgroundColor: Color {
        if colorScheme == .dark {
            return palette.foreground.color.opacity(0.18)
        }

        return palette.background.color
    }

    private var foregroundColor: Color {
        if colorScheme == .dark {
            return palette.background.color
        }

        return palette.foreground.color
    }

    private func downloadProgressLabel(for progress: Double) -> String {
        let percent = Int((min(max(progress, 0), 1) * 100).rounded())
        return "\(percent)%"
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
