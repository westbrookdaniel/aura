import SwiftUI

@MainActor
final class RecorderOverlayVisualState: ObservableObject {
    @Published var state: RecorderOverlayView.DisplayState
    @Published var level: CGFloat
    @Published var auraColor: AuraColorOption

    init(state: RecorderOverlayView.DisplayState, level: CGFloat, auraColor: AuraColorOption) {
        self.state = state
        self.level = level
        self.auraColor = auraColor
    }
}

struct RecorderOverlayView: View {
    enum DisplayState: Equatable {
        case recording
        case loading
        case error
        case warning(String)
    }

    @ObservedObject var visualState: RecorderOverlayVisualState

    var body: some View {
        ZStack(alignment: .bottom) {
            listeningAura
                .opacity(auraOpacity)

            switch visualState.state {
            case .recording, .error:
                Circle()
                    .fill(fillColor)
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: 0.10), value: scale)
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.black.opacity(0.16), radius: 10, y: 2)
                    .shadow(color: dotShadowColor, radius: dotShadowRadius)
                    .padding(.bottom, 26)
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color(red: 0.17, green: 0.28, blue: 0.44))
                    .scaleEffect(0.5)
                    .padding(0.2)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: dotShadowColor.opacity(0.65), radius: dotShadowRadius)
                    )
                    .environment(\.colorScheme, .light)
                    .padding(.bottom, 26)
            case .warning(let message):
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.25, green: 0.40, blue: 0.58))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.92, green: 0.97, blue: 1.00))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color(red: 0.67, green: 0.83, blue: 0.99).opacity(0.92), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color(red: 0.56, green: 0.80, blue: 1.00).opacity(0.20), radius: 20, y: 8)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var auraOpacity: CGFloat {
        switch visualState.state {
        case .recording:
            return 0.9
        case .loading:
            return 0.9
        case .error, .warning:
            return 0
        }
    }

    private var listeningAura: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            auraPalette.radialInner.opacity(0.98),
                            auraPalette.radialMiddle.opacity(0.66),
                            auraPalette.radialOuter.opacity(0.08)
                        ],
                        center: .center,
                        startRadius: 16,
                        endRadius: 170
                    )
                )
                .frame(width: 416, height: 234)
                .blur(radius: 22)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            auraPalette.baseInner.opacity(0.88),
                            auraPalette.baseOuter.opacity(0.40),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 343, height: 166)
                .blur(radius: 14)
        }
        .scaleEffect(0.5, anchor: .bottom)
        .offset(y: 110)
        .allowsHitTesting(false)
    }

    private var fillColor: Color {
        switch visualState.state {
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
        switch visualState.state {
        case .recording:
            let clampedLevel = min(max(visualState.level, 0), 1)
            return interpolatedRecordingScale(for: clampedLevel)
        case .loading:
            return 0.5
        case .error:
            return 1
        case .warning:
            return 1
        }
    }

    private var dotShadowColor: Color {
        auraPalette.shadow.opacity(0.72)
    }

    private var dotShadowRadius: CGFloat {
        28
    }

    private func interpolatedRecordingScale(for level: CGFloat) -> CGFloat {
        let minScale: CGFloat = 1.0
        let midScale: CGFloat = 2.2
        let maxScale: CGFloat = 3.0

        if level <= 0.4 {
            let progress = level / 0.4
            return minScale + (midScale - minScale) * progress
        }

        let progress = (level - 0.4) / 0.6
        return midScale + (maxScale - midScale) * progress
    }

    private var auraPalette: AuraPalette {
        switch visualState.auraColor {
        case .aqua:
            return AuraPalette(
                radialInner: Color(red: 0.55, green: 0.82, blue: 1.00),
                radialMiddle: Color(red: 0.42, green: 0.75, blue: 1.00),
                radialOuter: Color(red: 0.42, green: 0.75, blue: 1.00),
                baseInner: Color(red: 0.66, green: 0.88, blue: 1.00),
                baseOuter: Color(red: 0.33, green: 0.68, blue: 1.00),
                shadow: Color(red: 0.58, green: 0.83, blue: 1.00)
            )
        case .olive:
            return AuraPalette(
                radialInner: Color(red: 0.72, green: 0.80, blue: 0.42),
                radialMiddle: Color(red: 0.55, green: 0.66, blue: 0.28),
                radialOuter: Color(red: 0.55, green: 0.66, blue: 0.28),
                baseInner: Color(red: 0.79, green: 0.86, blue: 0.53),
                baseOuter: Color(red: 0.41, green: 0.50, blue: 0.19),
                shadow: Color(red: 0.64, green: 0.73, blue: 0.34)
            )
        case .magenta:
            return AuraPalette(
                radialInner: Color(red: 0.97, green: 0.50, blue: 0.86),
                radialMiddle: Color(red: 0.82, green: 0.31, blue: 0.68),
                radialOuter: Color(red: 0.82, green: 0.31, blue: 0.68),
                baseInner: Color(red: 0.98, green: 0.66, blue: 0.92),
                baseOuter: Color(red: 0.67, green: 0.20, blue: 0.55),
                shadow: Color(red: 0.90, green: 0.42, blue: 0.78)
            )
        case .sand:
            return AuraPalette(
                radialInner: Color(red: 0.96, green: 0.76, blue: 0.53),
                radialMiddle: Color(red: 0.85, green: 0.61, blue: 0.34),
                radialOuter: Color(red: 0.85, green: 0.61, blue: 0.34),
                baseInner: Color(red: 0.98, green: 0.84, blue: 0.64),
                baseOuter: Color(red: 0.73, green: 0.47, blue: 0.21),
                shadow: Color(red: 0.90, green: 0.69, blue: 0.44)
            )
        case .slate:
            return AuraPalette(
                radialInner: Color(red: 0.61, green: 0.71, blue: 0.82),
                radialMiddle: Color(red: 0.43, green: 0.53, blue: 0.65),
                radialOuter: Color(red: 0.43, green: 0.53, blue: 0.65),
                baseInner: Color(red: 0.73, green: 0.80, blue: 0.89),
                baseOuter: Color(red: 0.30, green: 0.39, blue: 0.50),
                shadow: Color(red: 0.52, green: 0.63, blue: 0.76)
            )
        }
    }
}

private struct AuraPalette {
    let radialInner: Color
    let radialMiddle: Color
    let radialOuter: Color
    let baseInner: Color
    let baseOuter: Color
    let shadow: Color
}
