import AppKit
import ServiceManagement
import SwiftUI

@main
struct ListenerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let appState = WhisperBarAppHolder.shared.appState
        statusController = StatusItemController(appState: appState)
        appState.start()
        appState.openSettingsWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        WhisperBarAppHolder.shared.appState.stop()
    }
}

@MainActor
final class WhisperBarAppHolder {
    static let shared = WhisperBarAppHolder()
    let appState = AppState()

    private init() {}
}
