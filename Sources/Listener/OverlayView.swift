import SwiftUI

struct RecorderOverlayView: View {
    let samples: [CGFloat]

    var body: some View {
        HStack(spacing: 0) {
            WaveformView(samples: samples)
                .frame(height: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            GlassPillBackground(
                tintTop: Color.white.opacity(0.03),
                tintBottom: Color.white.opacity(0.01),
                cornerRadius: 14
            )
        )
        .compositingGroup()
    }

}

struct AlertOverlayView: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            GlassPillBackground(
                tintTop: Color.red.opacity(0.28),
                tintBottom: Color.orange.opacity(0.14),
                cornerRadius: 16
            )
        )
    }
}

struct WaveformView: View {
    let samples: [CGFloat]

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    RoundedRectangle(cornerRadius: 1.1)
                        .fill(Color.white.opacity(0.96))
                        .frame(
                            width: max(1.2, (geometry.size.width / CGFloat(max(samples.count, 1))) - 2),
                            height: max(2, reactiveHeight(for: sample, in: geometry.size.height))
                        )
                        .animation(.snappy(duration: 0.08), value: sample)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func reactiveHeight(for sample: CGFloat, in totalHeight: CGFloat) -> CGFloat {
        let eased = pow(sample, 0.5)
        return max(2, eased * totalHeight)
    }
}

struct GlassPillBackground: View {
    var tintTop: Color = Color.white.opacity(0.14)
    var tintBottom: Color = Color.white.opacity(0.05)
    var cornerRadius: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.92),
                        Color.black.opacity(0.86)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tintTop, tintBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
    }
}
