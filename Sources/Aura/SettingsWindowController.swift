import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private static let windowSize = NSSize(width: 980, height: 760)
    private static let frameAutosaveName = "AuraSettingsWindow"

    private init() {
        let hostingController = NSHostingController(rootView: AnyView(EmptyView()))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Aura"
        window.titleVisibility = .hidden
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName(Self.frameAutosaveName)
        if window.setFrameUsingName(Self.frameAutosaveName) == false {
            Self.configureInitialFrame(for: window)
        }
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
            .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        let hostingController = NSHostingController(rootView: AnyView(rootView))
        contentViewController = hostingController
        updateAppearance(appState.preferences.appearance.nsAppearance)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateAppearance(_ appearance: NSAppearance?) {
        window?.appearance = appearance
        contentViewController?.view.appearance = appearance
    }

    func windowWillClose(_ notification: Notification) {
        window?.orderOut(nil)
    }

    private static func configureInitialFrame(for window: NSWindow) {
        window.setContentSize(Self.windowSize)

        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            window.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let frame = window.frame
        let centeredFrame = NSRect(
            x: visibleFrame.midX - (frame.width / 2),
            y: visibleFrame.midY - (frame.height / 2),
            width: frame.width,
            height: frame.height
        )
        window.setFrame(centeredFrame, display: false)
    }
}
