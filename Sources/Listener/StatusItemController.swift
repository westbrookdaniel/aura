import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configureMenu()
        bind()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Listener")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Listener"
            button.imagePosition = .imageOnly
            button.appearance = nil
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

    private func bind() {
        updateAppearance(appState.preferences.appearance.nsAppearance)

        appState.preferences.$appearance
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] appearance in
                self?.updateAppearance(appearance.nsAppearance)
            }
            .store(in: &cancellables)
    }

    private func updateAppearance(_ appearance: NSAppearance?) {
        menu.appearance = appearance
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
