import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private init() {
        let hostingController = NSHostingController(rootView: AnyView(EmptyView()))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Listener"
        window.setContentSize(NSSize(width: 740, height: 720))
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(appState: AppState) {
        let rootView = SettingsView()
            .environmentObject(appState)
            .frame(width: 740, height: 720)
        let hostingController = NSHostingController(rootView: AnyView(rootView))
        contentViewController = hostingController
        updateAppearance(appState.preferences.appearance.nsAppearance)
        window?.makeKeyAndOrderFront(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateAppearance(_ appearance: NSAppearance?) {
        window?.appearance = appearance
        contentViewController?.view.appearance = appearance
    }

    func windowWillClose(_ notification: Notification) {
        window?.orderOut(nil)
    }
}
