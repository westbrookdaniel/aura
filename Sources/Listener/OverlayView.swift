import SwiftUI

struct OverlayRootView: View {
    let samples: [CGFloat]
    let state: RecordingSessionState

    var body: some View {
        VStack(spacing: 10) {
            Text(labelText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))

            WaveformView(samples: samples)
                .frame(height: 28)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(.black.opacity(0.9))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var labelText: String {
        switch state {
        case .idle:
            return "Idle"
        case .recording:
            return "Listening…"
        case .transcribing:
            return "Transcribing…"
        case .inserting:
            return "Inserting…"
        case .error(let message):
            return message
        }
    }
}

struct WaveformView: View {
    let samples: [CGFloat]

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 4) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.95)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(
                            width: max(4, (geometry.size.width / CGFloat(max(samples.count, 1))) - 4),
                            height: max(6, sample * geometry.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}
