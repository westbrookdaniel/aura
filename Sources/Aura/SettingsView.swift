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
            return "General"
        }
    }

    var icon: String {
        switch self {
        case .history:
            return "clock.arrow.circlepath"
        case .settings:
            return "slider.horizontal.3"
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
        ZStack {
            pageBackground.ignoresSafeArea()

            HStack(spacing: 0) {
                ZStack(alignment: .trailing) {
                    sidebarBackground.ignoresSafeArea(edges: .top)

                    SettingsSidebar(
                        selectedDestination: $selectedDestination,
                        theme: theme
                    )
                }
                .frame(width: 214)
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
    }

    private var pageBackground: some View {
        ZStack(alignment: .topLeading) {
            Color(colorScheme == .dark ? NSColor.windowBackgroundColor : NSColor(calibratedWhite: 0.93, alpha: 1))

            LinearGradient(
                colors: [
                    theme.accentStrong.color.opacity(colorScheme == .dark ? 0.18 : 0.22),
                    theme.accentMuted.color.opacity(colorScheme == .dark ? 0.08 : 0.12),
                    theme.accentSoft.color.opacity(colorScheme == .dark ? 0.03 : 0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var sidebarBackground: some View {
        Color.white
            .opacity(colorScheme == .dark ? 0.03 : 0.36)
    }

    private var detailBackground: some View {
        Color.clear
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedDestination: SettingsDestination
    let theme: AuraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSidebarHeader(theme: theme)

            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SettingsSidebarHeader: View {
    let theme: AuraTheme

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.82))
                .frame(width: 28, height: 28)
                .overlay {
                    Image(nsImage: AuraStatusIcon.makeTemplateImage(size: 14))
                        .renderingMode(.template)
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.88) : .black.opacity(0.72))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.18)
                                : Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.06),
                    radius: 6,
                    x: 0,
                    y: 3
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("Aura")
                    .font(.system(size: 13, weight: .semibold))

                Text("Preferences")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
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
            HStack(spacing: 10) {
                Image(systemName: destination.icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)

                Text(destination.title)
                    .font(.system(size: 13, weight: .medium))

                Spacer()
            }
            .foregroundStyle(isSelected ? selectedTextColor : defaultTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
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

        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
}

private struct SettingsHomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var copiedFeedbackText: String?
    @State private var isClearHistoryConfirmationPresented = false

    let theme: AuraTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    Text("History")
                        .font(.system(size: 24, weight: .semibold))

                    Spacer()

                    if appState.preferences.voiceTextHistory.isEmpty == false {
                        HStack(spacing: 10) {
                            HistoryCopyFeedbackBanner(
                                isVisible: copiedFeedbackText != nil,
                                theme: theme
                            )

                            Button("Clear History") {
                                isClearHistoryConfirmationPresented = true
                            }
                            .buttonStyle(SettingsFlatButtonStyle(theme: theme))
                        }
                    }
                }

                VoiceResponseHistoryHomeCard(
                    items: appState.preferences.voiceTextHistory,
                    theme: theme,
                    onDelete: { appState.removeVoiceTextHistoryItem(id: $0.id) },
                    onCopy: handleCopy
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .animation(.easeInOut(duration: 0.18), value: copiedFeedbackText)
        .alert("Clear history?", isPresented: $isClearHistoryConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) {
                appState.clearVoiceTextHistory()
            }
        } message: {
            Text("This removes all saved transcripts from Aura history.")
        }
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

private struct SettingsDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isCapturingShortcut = false

    let theme: AuraTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("General")
                    .font(.system(size: 24, weight: .semibold))

                if let error = appState.lastErrorMessage, !error.isEmpty {
                    SettingsWarningCard(
                        title: "Warning",
                        message: error,
                        theme: theme,
                        dismiss: { appState.clearError() }
                    )
                }

                SettingsSection(theme: theme, title: "Shortcut") {
                    SettingsSimpleRow(title: "Press and hold") {
                        SettingsPopupButton(
                            options: ShortcutPreset.allCases.map {
                                SettingsPopupOption(id: $0.rawValue, title: $0.label)
                            },
                            selectedID: presetShortcutBinding.wrappedValue.rawValue,
                            width: 220
                        ) { selectedID in
                            guard let preset = ShortcutPreset(rawValue: selectedID) else { return }
                            presetShortcutBinding.wrappedValue = preset
                        }
                    }

                    if appState.preferences.shortcut.triggerKey == .customShortcut || isCapturingShortcut {
                        SettingsRowDivider()

                        SettingsSimpleRow(title: "Custom") {
                            VStack(alignment: .trailing, spacing: 10) {
                                SettingsValueBadge(text: customShortcutDisplayName)

                                ShortcutCaptureButton(
                                    isCapturing: $isCapturingShortcut,
                                    theme: theme
                                ) { shortcut in
                                    appState.updateShortcut(shortcut)
                                    isCapturingShortcut = false
                                }
                            }
                        }
                    }
                }

                SettingsSection(theme: theme, title: "Microphone") {
                    SettingsSimpleRow(title: "Input") {
                        SettingsPopupButton(
                            options: microphoneOptions,
                            selectedID: selectedMicrophoneID,
                            width: 260
                        ) { selectedID in
                            microphoneSelectionBinding.wrappedValue = microphoneID(from: selectedID)
                        }
                    }
                }

                SettingsSection(theme: theme, title: "Appearance") {
                    SettingsSimpleRow(title: "Accent") {
                        SettingsPopupButton(
                            options: AuraColorOption.allCases.map {
                                SettingsPopupOption(id: $0.rawValue, title: $0.label)
                            },
                            selectedID: auraColorBinding.wrappedValue.rawValue,
                            width: 220
                        ) { selectedID in
                            guard let option = AuraColorOption(rawValue: selectedID) else { return }
                            auraColorBinding.wrappedValue = option
                        }
                    }

                    SettingsRowDivider()

                    SettingsSimpleRow(title: "Mode") {
                        SettingsPopupButton(
                            options: AppAppearanceOption.allCases.map {
                                SettingsPopupOption(id: $0.rawValue, title: $0.label)
                            },
                            selectedID: appearanceBinding.wrappedValue.rawValue,
                            width: 220
                        ) { selectedID in
                            guard let option = AppAppearanceOption(rawValue: selectedID) else { return }
                            appearanceBinding.wrappedValue = option
                        }
                    }
                }

                SettingsSection(theme: theme, title: "Startup") {
                    SettingsSimpleRow(title: "Launch at login") {
                        Toggle("Launch at login", isOn: Binding(
                            get: { appState.isLaunchAtLoginEnabled },
                            set: { appState.setLaunchAtLogin(enabled: $0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(SettingsCheckboxToggleStyle(theme: theme))
                    }
                }

                SettingsSection(theme: theme, title: "Tools") {
                    SettingsSimpleRow(title: "Setup Assistant") {
                        Button("Redo Setup", action: appState.presentSetupOverlay)
                            .buttonStyle(SettingsFlatButtonStyle(theme: theme))
                    }

                    SettingsRowDivider()

                    SettingsSimpleRow(title: "Debug Transcriptions") {
                        Button("Open Folder", action: appState.openTranscriptionsFolder)
                            .buttonStyle(SettingsFlatButtonStyle(theme: theme))
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
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

    private var microphoneOptions: [SettingsPopupOption] {
        [SettingsPopupOption(id: "system", title: systemDefaultMicrophoneLabel)]
            + appState.availableMicrophones.map {
                SettingsPopupOption(id: String($0.stableID), title: $0.displayName)
            }
    }

    private var selectedMicrophoneID: String {
        if let id = microphoneSelectionBinding.wrappedValue {
            return String(id)
        }

        return "system"
    }

    private func microphoneID(from selectedID: String) -> UInt32? {
        selectedID == "system" ? nil : UInt32(selectedID)
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
                }
            }
        )
    }

    private var customShortcutDisplayName: String {
        if appState.preferences.shortcut.triggerKey == .customShortcut {
            return appState.preferences.shortcut.displayName
        }

        return "Not Set"
    }

}

private struct SettingsSectionEyebrow: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
            .padding(.horizontal, 2)
    }
}

private struct SettingsSection<Content: View>: View {
    let theme: AuraTheme
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionEyebrow(title)
            SettingsInsetGroup(theme: theme) {
                content
            }
        }
    }
}

private struct SettingsInsetGroup<Content: View>: View {
    let theme: AuraTheme
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardFillColor)
        )
    }

    private var cardFillColor: Color {
        if colorScheme == .dark {
            return theme.cardFill(for: colorScheme)
        }

        return .white
    }
}

private struct SettingsSimpleRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: Control

    private let controlColumnWidth: CGFloat = 260

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 16)

            control
                .frame(width: controlColumnWidth, alignment: .trailing)
        }
        .padding(.vertical, 12)
    }
}

private struct SettingsFlatButtonStyle: ButtonStyle {
    let theme: AuraTheme

    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.78))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(pressed: configuration.isPressed))
            )
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(pressed: Bool) -> Color {
        if colorScheme == .dark {
            return pressed ? Color.white.opacity(0.12) : Color.white.opacity(0.08)
        }

        return pressed ? Color.black.opacity(0.08) : Color.black.opacity(0.05)
    }
}

private struct SettingsCheckboxToggleStyle: ToggleStyle {
    let theme: AuraTheme

    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(boxFillColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(checkmarkColor)
                        .opacity(configuration.isOn ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuration.isOn ? "Enabled" : "Disabled")
    }

    private var boxFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var checkmarkColor: Color {
        colorScheme == .dark ? .white.opacity(0.88) : .black.opacity(0.78)
    }
}

private struct SettingsFlatFieldModifier: ViewModifier {
    let theme: AuraTheme

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )
    }
}

private struct SettingsPopupOption: Identifiable, Equatable {
    let id: String
    let title: String
}

private struct SettingsPopupButton: NSViewRepresentable {
    let options: [SettingsPopupOption]
    let selectedID: String
    let width: CGFloat
    let onChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionDidChange(_:))
        button.controlSize = .small
        button.bezelStyle = .rounded
        button.contentTintColor = .labelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.onChange = onChange

        let currentOptionIDs = button.itemArray.compactMap { $0.representedObject as? String }
        let nextOptionIDs = options.map(\.id)

        if currentOptionIDs != nextOptionIDs {
            button.removeAllItems()
            for option in options {
                let item = NSMenuItem(title: option.title, action: nil, keyEquivalent: "")
                item.representedObject = option.id
                button.menu?.addItem(item)
            }
        }

        if let item = button.itemArray.first(where: { ($0.representedObject as? String) == selectedID }) {
            button.select(item)
        }

        if let widthConstraint = button.constraints.first(where: { $0.firstAttribute == .width }) {
            widthConstraint.constant = width
        } else {
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
        }

        if let cell = button.cell as? NSPopUpButtonCell {
            cell.controlSize = .regular
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onChange: (String) -> Void

        init(onChange: @escaping (String) -> Void) {
            self.onChange = onChange
        }

        @objc func selectionDidChange(_ sender: NSPopUpButton) {
            guard let selectedID = sender.selectedItem?.representedObject as? String else { return }
            onChange(selectedID)
        }
    }
}

private extension View {
    func settingsFlatField(theme: AuraTheme) -> some View {
        modifier(SettingsFlatFieldModifier(theme: theme))
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
    let onCopy: (VoiceTextHistoryItem) -> Void

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if items.isEmpty {
                SettingsInsetGroup(theme: theme) {
                    Text("Your transcripts will show up here after a dictation.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            } else {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsSectionEyebrow(section.title)

                        VoiceResponseHistoryDaySectionCard(
                            section: section,
                            theme: theme,
                            onDelete: onDelete,
                            onCopy: onCopy
                        )
                    }
                }
            }
        }
    }

    private var sections: [HistoryDaySection] {
        HistorySectionBuilder.makeSections(from: items, calendar: calendar)
    }
}

private struct VoiceResponseHistoryDaySectionCard: View {
    let section: HistoryDaySection
    let theme: AuraTheme
    let onDelete: (VoiceTextHistoryItem) -> Void
    let onCopy: (VoiceTextHistoryItem) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SettingsInsetGroup(theme: theme) {
            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        SettingsRowDivider()
                    }

                    VoiceResponseHistoryTableRow(
                        item: item,
                        theme: theme,
                        onDelete: { onDelete(item) },
                        onCopy: { onCopy(item) }
                    )
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

    var body: some View {
        HStack(spacing: 12) {
            Button(action: copyText) {
                HStack(alignment: .top, spacing: 16) {
                    Text(timestamp)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)

                    Text(item.text)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Menu {
                Button("Copy", action: copyText)
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var timestamp: String {
        item.createdAt.formatted(date: .omitted, time: .shortened)
    }

    private func copyText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        onCopy()
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
                    color: theme.shadow.color.opacity(colorScheme == .dark ? 0.05 : 0.18),
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's get you set up")
                    .font(.system(size: 28, weight: .semibold))

                Text("Aura needs a few permissions and dependencies before it can start listening")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    SetupPermissionRow(
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
                        title: "Accessibility Access",
                        message: "Allows Aura to insert the transcript into the app where your cursor is currently focused.",
                        status: appState.permissionState.accessibility,
                        primaryAction: { appState.requestAccessibilityPermission() },
                        secondaryAction: { appState.openAccessibilitySettings() },
                        primaryTitle: "Prompt for Access",
                        secondaryTitle: "Open System Settings",
                        theme: theme
                    )

                    SetupPermissionRow(
                        title: "Input Monitoring",
                        message: "Allows Aura to detect your shortcut while you are working in other apps.",
                        status: appState.permissionState.inputMonitoring,
                        primaryAction: { appState.requestInputMonitoringPermission() },
                        secondaryAction: { appState.openInputMonitoringSettings() },
                        primaryTitle: "Prompt for Access",
                        secondaryTitle: "Open System Settings",
                        theme: theme
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    SetupModelDownloadSection(
                        state: appState.whisperModelSetupState,
                        retryAction: appState.retryWhisperModelDownload,
                        theme: theme
                    )
                }
            }

            HStack(spacing: 8) {
                Spacer()
                if canDismiss {
                    Button("Continue", action: onDismiss)
                        .buttonStyle(SettingsFlatButtonStyle(theme: theme))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark ? theme.cardFill(for: colorScheme) : Color.white)
        )
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
                        .buttonStyle(SettingsFlatButtonStyle(theme: theme))

                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(SettingsFlatButtonStyle(theme: theme))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.035))
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
                                .buttonStyle(SettingsFlatButtonStyle(theme: theme))
                        }
                    }

                    Spacer()

                    SetupModelStatusBadge(state: state, theme: theme)
                }

                switch state {
                case .checking:
                    ProgressView(value: 0, total: 1)
                        .tint(Color.gray)
                case .preparing:
                    ProgressView(value: 0, total: 1)
                        .tint(Color.gray)
                case .downloading(let progress, _):
                    ProgressView(value: progress, total: 1)
                        .tint(Color.gray)
                case .installed:
                    ProgressView(value: 1, total: 1)
                        .tint(Color.gray)
                case .failed:
                    ProgressView(value: 0, total: 1)
                        .tint(Color.gray)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(modelCardFill)
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
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.035)
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
