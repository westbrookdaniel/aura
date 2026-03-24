import SwiftUI

struct RecorderOverlayView: View {
    enum State {
        case recording
        case loading
        case error
        case warning(String)
    }

    let state: State
    let level: CGFloat

    var body: some View {
        Group {
            switch state {
            case .recording, .error:
                Circle()
                    .fill(fillColor)
                    .scaleEffect(scale)
                    .animation(.easeOut(duration: 0.10), value: scale)
                    .frame(width: 24, height: 24)
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.black.opacity(0.82))
                    .scaleEffect(0.5)
                    .padding(0.2)
                    .background(
                        Circle()
                            .fill(Color.white)
                    )
            case .warning(let message):
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.98, green: 0.86, blue: 0.69))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fillColor: Color {
        switch state {
        case .recording:
            return .white
        case .loading:
            return .clear
        case .error:
            return Color(red: 0.82, green: 0.16, blue: 0.16)
        case .warning:
            return .clear
        }
    }

    private var scale: CGFloat {
        switch state {
        case .recording:
            let clampedLevel = min(max(level, 0), 3)
            return 0.6 + clampedLevel * 4.15
        case .loading:
            return 0.5
        case .error:
            return 1
        case .warning:
            return 1
        }
    }
}
