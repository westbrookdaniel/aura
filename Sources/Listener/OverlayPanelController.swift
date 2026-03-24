import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private var recorderPanel: NSPanel?
    private var recorderHostingView: NSHostingView<RecorderOverlayView>?
    private var alertPanel: NSPanel?
    private var alertHostingView: NSHostingView<AlertOverlayView>?
    private var alertDismissTask: Task<Void, Never>?

    func showRecorder(samples: [CGFloat]) {
        if recorderPanel == nil {
            createRecorderPanel()
        }
        updateRecorder(samples: samples)
        positionPanels()
        recorderPanel?.orderFrontRegardless()
    }

    func updateRecorder(samples: [CGFloat]) {
        guard let recorderHostingView else { return }
        recorderHostingView.rootView = RecorderOverlayView(samples: samples)
        positionPanels()
    }

    func hideRecorder() {
        recorderPanel?.orderOut(nil)
    }

    func showAlert(message: String) {
        if alertPanel == nil {
            createAlertPanel()
        }
        alertHostingView?.rootView = AlertOverlayView(message: message)
        positionPanels()
        alertPanel?.orderFrontRegardless()

        alertDismissTask?.cancel()
        alertDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                self?.hideAlert()
            }
        }
    }

    func hideAlert() {
        alertDismissTask?.cancel()
        alertDismissTask = nil
        alertPanel?.orderOut(nil)
    }

    func hideAll() {
        hideRecorder()
        hideAlert()
    }

    private func createRecorderPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 196, height: 42),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        let host = NSHostingView(rootView: RecorderOverlayView(samples: Array(repeating: 0, count: 24)))
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        self.recorderPanel = panel
        self.recorderHostingView = host
    }

    private func createAlertPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 68),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        let host = NSHostingView(rootView: AlertOverlayView(message: ""))
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        self.alertPanel = panel
        self.alertHostingView = host
    }

    private func positionPanels() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }

        if let recorderPanel {
            let width = recorderPanel.frame.width
            let height = recorderPanel.frame.height
            let x = frame.midX - (width / 2)
            let y = frame.minY + 26
            recorderPanel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }

        if let alertPanel {
            let width = alertPanel.frame.width
            let height = alertPanel.frame.height
            let x = frame.midX - (width / 2)
            let y = frame.minY + 164
            alertPanel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
    }
}
