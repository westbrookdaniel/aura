import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private let fadeDuration: TimeInterval = 0.18
    private let loadingDelay: Duration = .milliseconds(500)
    private let loadingSettleDelay: Duration = .milliseconds(120)

    private enum IndicatorState {
        case recording
        case loading
        case error
        case warning(String)
    }

    private var recorderPanel: NSPanel?
    private var recorderHostingView: NSHostingView<RecorderOverlayView>?
    private var alertDismissTask: Task<Void, Never>?
    private var loadingTask: Task<Void, Never>?
    private var indicatorState: IndicatorState = .recording
    private var currentLevel: CGFloat = 0.18
    private let visualState = RecorderOverlayVisualState(state: .recording, level: 0.18, auraColor: .aqua)

    func updateAuraColor(_ auraColor: AuraColorOption) {
        visualState.auraColor = auraColor
    }

    func showRecorder(samples: [CGFloat]) {
        cancelTransientTasks()
        if recorderPanel == nil {
            createRecorderPanel()
        }
        indicatorState = .recording
        updateRecorder(samples: samples)
        positionPanels()
        recorderPanel?.alphaValue = 1
        recorderPanel?.orderFrontRegardless()
    }

    func updateRecorder(samples: [CGFloat]) {
        guard recorderHostingView != nil else { return }
        currentLevel = samples.isEmpty ? 0.18 : samples.reduce(0, +) / CGFloat(samples.count)
        let state: RecorderOverlayView.DisplayState
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
        visualState.state = state
        visualState.level = currentLevel
        positionPanels()
    }

    func hideRecorder() {
        cancelTransientTasks()
        fadeOutRecorder()
    }

    func showAlert(message: String) {
        cancelTransientTasks()
        if recorderPanel == nil {
            createRecorderPanel()
        }
        indicatorState = .error
        visualState.state = .error
        visualState.level = 0
        positionPanels()
        fadeInRecorder()

        alertDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                self?.hideRecorder()
            }
        }
    }

    func showLoading() {
        cancelTransientTasks()
        currentLevel = 0
        if case .recording = indicatorState {
            visualState.level = 0
        }

        loadingTask = Task { [weak self] in
            try? await Task.sleep(for: self?.loadingSettleDelay ?? .zero)
            try? await Task.sleep(for: self?.loadingDelay ?? .zero)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.presentLoadingIfNeeded()
            }
        }
    }

    func showClippedStartWarning() {
        showWarning(message: "Try waiting longer before talking")
    }

    func showShortHoldWarning() {
        showWarning(message: "Hold the button while you talk")
    }

    private func showWarning(message: String) {
        cancelTransientTasks()
        if recorderPanel == nil {
            createRecorderPanel()
        }
        indicatorState = .warning(message)
        visualState.state = .warning(message)
        visualState.level = 0
        positionPanels()
        fadeInRecorder()

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
        let initialSize = overlaySize(for: NSScreen.main ?? NSScreen.screens.first)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialSize.width, height: initialSize.height),
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
        panel.alphaValue = 1

        let host = NSHostingView(rootView: RecorderOverlayView(visualState: visualState))
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
            let overlaySize = overlaySize(for: screen)
            resizeRecorderPanel(to: overlaySize)
            let width = recorderPanel.frame.width
            let height = recorderPanel.frame.height
            let x = frame.minX
            let y = frame.minY - (height * 0.25)
            recorderPanel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
    }

    private func presentLoadingIfNeeded() {
        if recorderPanel == nil {
            createRecorderPanel()
        }
        guard let recorderPanel else { return }
        indicatorState = .loading
        visualState.state = .loading
        visualState.level = 0
        positionPanels()
        recorderPanel.orderFrontRegardless()
        recorderPanel.alphaValue = 1
    }

    private func overlaySize(for screen: NSScreen?) -> NSSize {
        guard let frame = screen?.visibleFrame else {
            return NSSize(width: 1280, height: 420)
        }

        return NSSize(width: frame.width, height: max(frame.height * 0.5, 320))
    }

    private func fadeInRecorder() {
        guard let recorderPanel else { return }
        recorderPanel.alphaValue = 0
        recorderPanel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            recorderPanel.animator().alphaValue = 1
        }
    }

    private func fadeOutRecorder() {
        guard let recorderPanel else { return }
        let panel = recorderPanel
        if !panel.isVisible {
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
    }

    private func cancelTransientTasks() {
        alertDismissTask?.cancel()
        alertDismissTask = nil
        loadingTask?.cancel()
        loadingTask = nil
    }
}
