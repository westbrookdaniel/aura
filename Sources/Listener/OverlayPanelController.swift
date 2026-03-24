import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private enum IndicatorState {
        case recording
        case loading
        case error
        case warning(String)
    }

    private var recorderPanel: NSPanel?
    private var recorderHostingView: NSHostingView<RecorderOverlayView>?
    private var alertDismissTask: Task<Void, Never>?
    private var indicatorState: IndicatorState = .recording
    private var currentLevel: CGFloat = 0.18

    func showRecorder(samples: [CGFloat]) {
        if recorderPanel == nil {
            createRecorderPanel()
        }
        indicatorState = .recording
        updateRecorder(samples: samples)
        positionPanels()
        recorderPanel?.orderFrontRegardless()
    }

    func updateRecorder(samples: [CGFloat]) {
        guard let recorderHostingView else { return }
        currentLevel = samples.isEmpty ? 0.18 : samples.reduce(0, +) / CGFloat(samples.count)
        let state: RecorderOverlayView.State
        switch indicatorState {
        case .recording:
            state = .recording
        case .loading:
            state = .loading
        case .error:
            state = .error
        case .warning(let message):
            state = .warning(message)
        }
        recorderHostingView.rootView = RecorderOverlayView(
            state: state,
            level: currentLevel
        )
        positionPanels()
    }

    func hideRecorder() {
        alertDismissTask?.cancel()
        alertDismissTask = nil
        recorderPanel?.orderOut(nil)
    }

    func showAlert(message: String) {
        if recorderPanel == nil {
            createRecorderPanel()
        }
        indicatorState = .error
        recorderHostingView?.rootView = RecorderOverlayView(state: .error, level: 0)
        positionPanels()
        recorderPanel?.orderFrontRegardless()

        alertDismissTask?.cancel()
        alertDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                self?.hideRecorder()
            }
        }
    }

    func showLoading() {
        if recorderPanel == nil {
            createRecorderPanel()
        }
        alertDismissTask?.cancel()
        alertDismissTask = nil
        indicatorState = .loading
        recorderHostingView?.rootView = RecorderOverlayView(state: .loading, level: 0)
        resizeRecorderPanel(to: NSSize(width: 54, height: 54))
        positionPanels()
        recorderPanel?.orderFrontRegardless()
    }

    func showClippedStartWarning() {
        showWarning(message: "Try waiting longer before talking")
    }

    func showShortHoldWarning() {
        showWarning(message: "Hold the button while you talk")
    }

    private func showWarning(message: String) {
        if recorderPanel == nil {
            createRecorderPanel()
        }
        indicatorState = .warning(message)
        recorderHostingView?.rootView = RecorderOverlayView(
            state: .warning(message),
            level: 0
        )
        resizeRecorderPanel(to: NSSize(width: 248, height: 44))
        positionPanels()
        recorderPanel?.orderFrontRegardless()

        alertDismissTask?.cancel()
        alertDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run {
                self?.hideRecorder()
            }
        }
    }

    func hideAlert() {
        hideRecorder()
    }

    func hideAll() {
        hideRecorder()
    }

    private func createRecorderPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 54, height: 54),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true

        let host = NSHostingView(rootView: RecorderOverlayView(state: .recording, level: 0.18))
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        self.recorderPanel = panel
        self.recorderHostingView = host
    }

    private func resizeRecorderPanel(to size: NSSize) {
        guard let recorderPanel else { return }
        let origin = recorderPanel.frame.origin
        recorderPanel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func positionPanels() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }

        if let recorderPanel {
            switch indicatorState {
            case .recording, .loading:
                resizeRecorderPanel(to: NSSize(width: 54, height: 54))
            case .error, .warning:
                break
            }
            let width = recorderPanel.frame.width
            let height = recorderPanel.frame.height
            let x = frame.midX - (width / 2)
            let y = frame.minY + 22
            recorderPanel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
    }
}
