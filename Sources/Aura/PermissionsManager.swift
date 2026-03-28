import AVFoundation
@preconcurrency import ApplicationServices
import Cocoa
import Foundation

struct PermissionsManager {
    func currentState() -> PermissionState {
        PermissionState(
            microphone: microphoneState(),
            accessibility: accessibilityState(),
            inputMonitoring: inputMonitoringState()
        )
    }

    func requestMicrophoneAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func requestInputMonitoringAccess() {
        _ = CGRequestListenEventAccess()
    }

    func openAccessibilitySettings() {
        openSettingsPane(anchor: "Privacy_Accessibility")
    }

    func openMicrophoneSettings() {
        openSettingsPane(anchor: "Privacy_Microphone")
    }

    func openInputMonitoringSettings() {
        openSettingsPane(anchor: "Privacy_ListenEvent")
    }

    private func openSettingsPane(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func microphoneState() -> PermissionAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    private func accessibilityState() -> PermissionAuthorization {
        AXIsProcessTrusted() ? .granted : .denied
    }

    private func inputMonitoringState() -> PermissionAuthorization {
        let trusted = CGPreflightListenEventAccess()
        if trusted { return .granted }
        return .denied
    }
}
