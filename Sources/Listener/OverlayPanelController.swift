import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayRootView>?

    func show(samples: [CGFloat], state: RecordingSessionState) {
        if panel == nil {
            createPanel()
        }
        update(samples: samples, state: state)
        positionPanel()
        panel?.orderFrontRegardless()
    }

    func update(samples: [CGFloat], state: RecordingSessionState) {
        guard let hostingView else { return }
        hostingView.rootView = OverlayRootView(samples: samples, state: state)
        positionPanel()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 92),
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

        let host = NSHostingView(rootView: OverlayRootView(samples: Array(repeating: 0, count: 24), state: .idle))
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        self.panel = panel
        self.hostingView = host
    }

    private func positionPanel() {
        guard let panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let width = panel.frame.width
        let height = panel.frame.height
        let x = frame.midX - (width / 2)
        let y = frame.minY + 48
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
