import AppKit
import SwiftUI

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Listener")
            button.toolTip = "Listener"
            button.imagePosition = .imageOnly
        }

        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: "State: \(appState.sessionState.title)", action: nil, keyEquivalent: "")
        menu.addItem(statusItem)

        let shortcutItem = NSMenuItem(title: "Shortcut: \(appState.preferences.shortcut.displayName)", action: nil, keyEquivalent: "")
        menu.addItem(shortcutItem)

        if !appState.lastTranscript.isEmpty {
            let transcriptItem = NSMenuItem(title: "Last transcript: \(appState.lastTranscript)", action: nil, keyEquivalent: "")
            transcriptItem.isEnabled = false
            menu.addItem(transcriptItem)
        }

        if let error = appState.lastErrorMessage {
            let errorItem = NSMenuItem(title: "Error: \(error)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).configured(target: self))

        menu.addItem(NSMenuItem(
            title: "Microphone Permission",
            action: #selector(requestMicrophonePermission),
            keyEquivalent: ""
        ).configured(target: self))

        menu.addItem(NSMenuItem(
            title: "Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        ).configured(target: self))

        menu.addItem(NSMenuItem(
            title: "Input Monitoring Settings",
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        ).configured(target: self))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Listener",
            action: #selector(quit),
            keyEquivalent: "q"
        ).configured(target: self))

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func requestMicrophonePermission() {
        Task { await appState.requestMicrophonePermission() }
    }

    @objc private func openAccessibilitySettings() {
        appState.openAccessibilitySettings()
    }

    @objc private func openInputMonitoringSettings() {
        appState.openInputMonitoringSettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private extension NSMenuItem {
    func configured(target: AnyObject?) -> NSMenuItem {
        self.target = target
        return self
    }
}
