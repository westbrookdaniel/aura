import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let menu = NSMenu()

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configureMenu()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Listener")
            button.toolTip = "Listener"
            button.imagePosition = .imageOnly
        }
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.delegate = self

        menu.addItem(NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).configured(target: self))

        menu.addItem(NSMenuItem(
            title: "Quit Listener",
            action: #selector(quit),
            keyEquivalent: "q"
        ).configured(target: self))
    }

    @objc private func openSettings() {
        appState.openSettingsWindow()
        NSApp.activate(ignoringOtherApps: true)
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
