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
    @State private var loadingPulse = false

    private struct AuraMetrics {
        let outerSize: CGSize
        let innerSize: CGSize
        let radialEndRadius: CGFloat
        let outerBlur: CGFloat
        let innerBlur: CGFloat
        let outerOpacity: CGFloat
        let innerOpacity: CGFloat
        let xScale: CGFloat
        let yScale: CGFloat
        let yOffset: CGFloat
    }

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
            switch visualState.state {
            case .recording(let isProcessing):
                ZStack(alignment: .bottom) {
                    listeningAura(isProcessing: isProcessing)
                        .opacity(auraDisplayOpacity(isProcessing: isProcessing))
                        .scaleEffect(loadingScale(isProcessing: isProcessing), anchor: .bottom)
                        .animation(.easeInOut(duration: 0.12), value: recordingLevel)
                        .animation(.easeInOut(duration: 0.20), value: isProcessing)
                        .animation(.easeInOut(duration: 0.82), value: loadingPulse)
                        .onAppear {
                            updateLoadingPulse(isProcessing)
                        }
                        .onChange(of: isProcessing) { newValue in
                            updateLoadingPulse(newValue)
                        }

                    if isProcessing {
                        loadingIndicator
                            .padding(.bottom, 26)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
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
                    .offset(y: 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: visualState.state)
    }

    private var loadingIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: loadingIndicatorDiameter, height: loadingIndicatorDiameter)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.12), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 10, y: 3)

            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.black.opacity(0.55))
                .scaleEffect(0.52)
        }
        .frame(width: loadingIndicatorDiameter + 6, height: loadingIndicatorDiameter + 6)
    }

    private var auraOpacity: CGFloat {
        switch visualState.state {
        case .recording:
            return 0.9
        case .alert:
            return 0
        }
    }

    private func listeningAura(isProcessing: Bool) -> some View {
        let metrics = auraMetrics(isProcessing: isProcessing)

        return ZStack(alignment: .bottom) {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.overlay.radialInner.color.opacity(metrics.outerOpacity),
                            theme.overlay.radialMiddle.color.opacity(metrics.innerOpacity),
                            theme.overlay.radialOuter.color.opacity(isProcessing ? 0.18 : 0.08)
                        ],
                        center: .center,
                        startRadius: 16,
                        endRadius: metrics.radialEndRadius
                    )
                )
                .frame(width: metrics.outerSize.width, height: metrics.outerSize.height)
                .blur(radius: metrics.outerBlur)
                .shadow(color: auraShadowColor(isProcessing: isProcessing), radius: isProcessing ? 22 : 34, y: isProcessing ? 0 : -4)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.overlay.baseInner.color.opacity(metrics.outerOpacity),
                            theme.overlay.baseOuter.color.opacity(isProcessing ? 0.74 : 0.40),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: metrics.innerSize.width, height: metrics.innerSize.height)
                .blur(radius: metrics.innerBlur)
        }
        .scaleEffect(x: metrics.xScale, y: metrics.yScale, anchor: .bottom)
        .offset(y: metrics.yOffset)
        .allowsHitTesting(false)
    }

    private var recordingLevel: CGFloat {
        guard case .recording(false) = visualState.state else { return 0 }
        return min(max(visualState.level, 0), 1)
    }

    private func auraDisplayOpacity(isProcessing: Bool) -> CGFloat {
        guard isProcessing else { return auraOpacity }
        return loadingPulse ? 0.94 : 0.84
    }

    private func loadingScale(isProcessing: Bool) -> CGFloat {
        guard isProcessing else { return 1 }
        return loadingPulse ? 1.02 : 0.98
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

    private var loadingIndicatorDiameter: CGFloat {
        28
    }

    private func auraMetrics(isProcessing: Bool) -> AuraMetrics {
        if isProcessing {
            return AuraMetrics(
                outerSize: CGSize(width: 416, height: 234),
                innerSize: CGSize(width: 343, height: 166),
                radialEndRadius: 170,
                outerBlur: 22,
                innerBlur: 14,
                outerOpacity: 0.94,
                innerOpacity: 0.74,
                xScale: 0.54,
                yScale: 0.44,
                yOffset: 112
            )
        }

        let level = recordingLevel
        return AuraMetrics(
            outerSize: CGSize(
                width: 416 + (level * 108),
                height: 234 + (level * 42)
            ),
            innerSize: CGSize(
                width: 343 + (level * 84),
                height: 166 + (level * 36)
            ),
            radialEndRadius: 170 + (level * 34),
            outerBlur: 22 + (level * 5),
            innerBlur: 14 + (level * 3),
            outerOpacity: 0.98,
            innerOpacity: 0.66 + (level * 0.14),
            xScale: 0.54 + (level * 0.20),
            yScale: 0.44 + (level * 0.28),
            yOffset: 112 - (level * 18)
        )
    }

    private func auraShadowColor(isProcessing: Bool) -> Color {
        if isProcessing {
            return theme.overlay.shadow.color.opacity(0.50)
        }

        return theme.overlay.shadow.color.opacity(0.32 + (recordingLevel * 0.12))
    }

    private func updateLoadingPulse(_ isProcessing: Bool) {
        guard isProcessing else {
            withAnimation(.easeOut(duration: 0.18)) {
                loadingPulse = false
            }
            return
        }

        loadingPulse = false
        withAnimation(.easeInOut(duration: 0.82).repeatForever(autoreverses: true)) {
            loadingPulse = true
        }
    }
}
