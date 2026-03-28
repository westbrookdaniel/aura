import AppKit
import ServiceManagement
import SwiftUI

@main
struct AuraApp: App {
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

        let appState = AuraAppHolder.shared.appState
        statusController = StatusItemController(appState: appState)
        appState.start()

        if appState.requiresSetup {
            appState.openSettingsWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AuraAppHolder.shared.appState.stop()
    }
}

@MainActor
final class AuraAppHolder {
    static let shared = AuraAppHolder()
    let appState = AppState()

    private init() {}
}
