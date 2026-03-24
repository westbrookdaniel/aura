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
            .animation(.easeOut(duration: 0.10), value: scale)
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
            let clampedLevel = min(max(level, 0), 1)
            return 0.72 + clampedLevel * 1.75
        case .error:
            return 1
        }
    }
}
