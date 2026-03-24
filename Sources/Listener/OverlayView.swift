import SwiftUI

struct RecorderOverlayView: View {
    enum State {
        case recording
        case error
    }

    let state: State
    let level: CGFloat

    var body: some View {
        Circle()
            .fill(fillColor)
            .scaleEffect(scale)
            .animation(.easeOut(duration: 0.08), value: scale)
            .frame(width: 18, height: 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fillColor: Color {
        switch state {
        case .recording:
            return .white
        case .error:
            return Color(red: 0.82, green: 0.16, blue: 0.16)
        }
    }

    private var scale: CGFloat {
        switch state {
        case .recording:
            return 1 + min(max(level, 0), 1) * 1.15
        case .error:
            return 1
        }
    }
}
