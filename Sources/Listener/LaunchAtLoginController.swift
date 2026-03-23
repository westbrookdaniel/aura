import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    static let shared = LaunchAtLoginController()

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func enable() throws {
        try SMAppService.mainApp.register()
    }

    func disable() throws {
        try SMAppService.mainApp.unregister()
    }
}
