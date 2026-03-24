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
    @Environment(\.colorScheme) private var colorScheme

    enum AlertSeverity: Equatable {
        case warning
        case error
    }

    enum DisplayState: Equatable {
        case recording(isProcessing: Bool)
        case alert(message: String, severity: AlertSeverity)
    }

    @ObservedObject var visualState: RecorderOverlayVisualState

    var body: some View {
        ZStack(alignment: .bottom) {
            listeningAura
                .opacity(auraOpacity)

            switch visualState.state {
            case .recording(let isProcessing):
                ZStack {
                    Circle()
                        .fill(recordingDotColor)
                        .scaleEffect(scale)
                        .animation(.easeInOut(duration: 0.10), value: scale)
                        .frame(width: indicatorDiameter, height: indicatorDiameter)
                        .shadow(color: dotShadowColor, radius: 6, y: 0)
                        .shadow(color: dotShadowColor, radius: dotShadowRadius)

                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(processingTintColor)
                        .scaleEffect(0.5)
                        .opacity(isProcessing ? 1 : 0)
                        .animation(.easeInOut(duration: 0.18), value: isProcessing)
                }
                .padding(indicatorPadding)
                .padding(.bottom, 26)
            case .alert(let message, _):
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(alertTextColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(alertBackgroundColor)
                    )
                    .shadow(color: alertShadowColor, radius: 20, y: 8)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var auraOpacity: CGFloat {
        switch visualState.state {
        case .recording:
            return 0.9
        case .alert:
            return 0
        }
    }

    private var listeningAura: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.overlay.radialInner.color.opacity(0.98),
                            theme.overlay.radialMiddle.color.opacity(0.66),
                            theme.overlay.radialOuter.color.opacity(0.08)
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
                            theme.overlay.baseInner.color.opacity(0.88),
                            theme.overlay.baseOuter.color.opacity(0.40),
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

    private var scale: CGFloat {
        switch visualState.state {
        case .recording(false):
            let clampedLevel = min(max(visualState.level, 0), 1)
            return interpolatedRecordingScale(for: clampedLevel)
        case .recording(true):
            return 1
        case .alert:
            return 1
        }
    }

    private var dotShadowColor: Color {
        theme.loadingTint(for: colorScheme).opacity(0.2)
    }

    private var dotShadowRadius: CGFloat {
        28
    }

    private var indicatorDiameter: CGFloat {
        28
    }

    private var indicatorPadding: CGFloat {
        2
    }

    private var recordingDotColor: Color {
        theme.neutralSurface(for: colorScheme, emphasized: true)
    }

    private var processingTintColor: Color {
        theme.loadingTint(for: colorScheme)
    }

    private var alertSeverity: AlertSeverity {
        switch visualState.state {
        case .recording:
            return .warning
        case .alert(_, let severity):
            return severity
        }
    }

    private var alertTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var alertBackgroundColor: Color {
        switch alertSeverity {
        case .warning:
            return theme.warningBackground(for: colorScheme)
        case .error:
            return alertPalette.background.color
        }
    }

    private var alertBorderColor: Color {
        switch alertSeverity {
        case .warning:
            return theme.warningBorder(for: colorScheme)
        case .error:
            return alertPalette.border.color
        }
    }

    private var alertShadowColor: Color {
        switch alertSeverity {
        case .warning:
            return theme.warningShadow(for: colorScheme)
        case .error:
            return theme.error.border.color.opacity(colorScheme == .dark ? 0.32 : 0.22)
        }
    }

    private var alertPalette: AuraTheme.StatusPalette {
        switch alertSeverity {
        case .warning:
            return theme.warning
        case .error:
            return theme.error
        }
    }

    private var theme: AuraTheme {
        visualState.auraColor.theme
    }

    private func interpolatedRecordingScale(for level: CGFloat) -> CGFloat {
        let minScale: CGFloat = 0.5
        let midScale: CGFloat = 1.4
        let maxScale: CGFloat = 1.8

        if level <= 0.4 {
            let progress = level / 0.4
            return minScale + (midScale - minScale) * progress
        }

        let progress = (level - 0.4) / 0.6
        return midScale + (maxScale - midScale) * progress
    }

}
