import SwiftUI

struct ThemeColor: Equatable, Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct AuraTheme: Equatable {
    struct OverlayPalette: Equatable {
        let radialInner: ThemeColor
        let radialMiddle: ThemeColor
        let radialOuter: ThemeColor
        let baseInner: ThemeColor
        let baseOuter: ThemeColor
        let shadow: ThemeColor
    }

    struct StatusPalette: Equatable {
        let background: ThemeColor
        let foreground: ThemeColor
        let border: ThemeColor
    }

    let overlay: OverlayPalette
    let accentStrong: ThemeColor
    let accentText: ThemeColor
    let accentSoft: ThemeColor
    let accentMuted: ThemeColor
    let accentBorder: ThemeColor
    let shadow: ThemeColor
    let warning: StatusPalette
    let success: StatusPalette
    let error: StatusPalette
    let neutral: StatusPalette

    func neutralSurface(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if colorScheme == .dark {
            let opacity = emphasized ? 1 : 0.84
            return ThemeColor(red: 0.12, green: 0.12, blue: 0.12, opacity: opacity).color
        }

        let opacity = emphasized ? 0.98 : 0.88
        return ThemeColor(red: 0.98, green: 0.98, blue: 0.98, opacity: opacity).color
    }

    func neutralBorder(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if colorScheme == .dark {
            return ThemeColor(red: 0.34, green: 0.34, blue: 0.34, opacity: emphasized ? 0.62 : 0.42).color
        }

        return ThemeColor(red: 0.84, green: 0.84, blue: 0.84, opacity: emphasized ? 0.96 : 0.82).color
    }

    func loadingTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? overlay.baseInner.color : accentText.color
    }

    func loadingBackground(for colorScheme: ColorScheme) -> Color {
        neutralSurface(for: colorScheme, emphasized: true)
    }

    func warningShadow(for colorScheme: ColorScheme) -> Color {
        shadow.color.opacity(colorScheme == .dark ? 0.26 : 0.18)
    }

    func warningBackground(for colorScheme: ColorScheme) -> Color {
        neutralSurface(for: colorScheme, emphasized: true)
    }

    func warningBorder(for colorScheme: ColorScheme) -> Color {
        warning.border.color.opacity(colorScheme == .dark ? 0.68 : 0.94)
    }

    func setupGradient(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .dark {
            return [
                overlay.baseOuter.color.opacity(0.42),
                ThemeColor(red: 0.10, green: 0.10, blue: 0.10).color,
                ThemeColor(red: 0.08, green: 0.08, blue: 0.08).color
            ]
        }

        return [
            overlay.baseInner.color.opacity(0.46),
            ThemeColor(red: 0.99, green: 0.99, blue: 0.99).color,
            ThemeColor(red: 0.98, green: 0.98, blue: 0.98).color
        ]
    }

    func setupBorder(for colorScheme: ColorScheme) -> Color {
        accentBorder.color.opacity(colorScheme == .dark ? 0.44 : 0.58)
    }

    func cardFill(for colorScheme: ColorScheme) -> Color {
        neutralSurface(for: colorScheme)
    }

    func cardTint(for colorScheme: ColorScheme) -> Color {
        .clear
    }

    func cardBorder(for colorScheme: ColorScheme) -> Color {
        neutralBorder(for: colorScheme)
    }

    func historyRowFill(for colorScheme: ColorScheme) -> Color {
        neutralSurface(for: colorScheme, emphasized: true)
    }

    func historyRowBorder(for colorScheme: ColorScheme) -> Color {
        neutralBorder(for: colorScheme)
    }

    func reflectiveButtonLabel(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? ThemeColor(red: 0.98, green: 0.99, blue: 1.00, opacity: 0.94).color
            : accentText.color.opacity(0.94)
    }

    func reflectiveButtonBackground(isPressed: Bool, colorScheme: ColorScheme) -> Color {
        neutralSurface(for: colorScheme, emphasized: isPressed)
    }

    func reflectiveButtonPrimaryStroke(for colorScheme: ColorScheme) -> Color {
        neutralBorder(for: colorScheme, emphasized: true)
    }

    func reflectiveButtonSecondaryStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? ThemeColor(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.26).color
            : ThemeColor(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.06).color
    }

    func ghostButtonLabel(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? ThemeColor(red: 0.88, green: 0.88, blue: 0.88, opacity: 0.94).color
            : ThemeColor(red: 0.20, green: 0.20, blue: 0.20, opacity: 0.92).color
    }

    func ghostButtonBackground(isPressed: Bool, colorScheme: ColorScheme) -> Color {
        neutralSurface(for: colorScheme).opacity(isPressed ? 1.0 : 0.74)
    }

    func ghostButtonPrimaryStroke(for colorScheme: ColorScheme) -> Color {
        neutralBorder(for: colorScheme)
    }

    func ghostButtonSecondaryStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? ThemeColor(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.22).color
            : ThemeColor(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.05).color
    }

    func primaryButtonFill(isPressed: Bool, colorScheme: ColorScheme) -> Color {
        accentStrong.color.opacity(isPressed ? (colorScheme == .dark ? 0.84 : 0.92) : 1.0)
    }

    func primaryButtonBorder(for colorScheme: ColorScheme) -> Color {
        overlay.baseInner.color.opacity(colorScheme == .dark ? 0.28 : 0.38)
    }

    func warningCardBackground(for colorScheme: ColorScheme) -> Color {
        neutralSurface(for: colorScheme, emphasized: true)
    }

    func warningCardBorder(for colorScheme: ColorScheme) -> Color {
        warning.border.color.opacity(colorScheme == .dark ? 0.54 : 0.40)
    }

    func divider(for colorScheme: ColorScheme) -> Color {
        neutralBorder(for: colorScheme)
    }

    func badgePalette(for status: PermissionAuthorization) -> StatusPalette {
        switch status {
        case .granted:
            return success
        case .denied:
            return error
        case .notDetermined:
            return neutral
        }
    }
}

extension AuraColorOption {
    var theme: AuraTheme {
        switch self {
        case .aqua:
            return AuraTheme(
                overlay: .init(
                    radialInner: ThemeColor(red: 0.55, green: 0.82, blue: 1.00),
                    radialMiddle: ThemeColor(red: 0.42, green: 0.75, blue: 1.00),
                    radialOuter: ThemeColor(red: 0.42, green: 0.75, blue: 1.00),
                    baseInner: ThemeColor(red: 0.66, green: 0.88, blue: 1.00),
                    baseOuter: ThemeColor(red: 0.33, green: 0.68, blue: 1.00),
                    shadow: ThemeColor(red: 0.58, green: 0.83, blue: 1.00)
                ),
                accentStrong: ThemeColor(red: 0.23, green: 0.53, blue: 0.98),
                accentText: ThemeColor(red: 0.17, green: 0.28, blue: 0.44),
                accentSoft: ThemeColor(red: 0.89, green: 0.94, blue: 1.00),
                accentMuted: ThemeColor(red: 0.67, green: 0.83, blue: 0.99),
                accentBorder: ThemeColor(red: 0.48, green: 0.73, blue: 0.98),
                shadow: ThemeColor(red: 0.56, green: 0.80, blue: 1.00),
                warning: .init(
                    background: ThemeColor(red: 0.92, green: 0.97, blue: 1.00),
                    foreground: ThemeColor(red: 0.25, green: 0.40, blue: 0.58),
                    border: ThemeColor(red: 0.67, green: 0.83, blue: 0.99)
                ),
                success: .init(
                    background: ThemeColor(red: 0.87, green: 0.96, blue: 0.94),
                    foreground: ThemeColor(red: 0.13, green: 0.50, blue: 0.42),
                    border: ThemeColor(red: 0.40, green: 0.78, blue: 0.67)
                ),
                error: .init(
                    background: ThemeColor(red: 0.98, green: 0.89, blue: 0.90),
                    foreground: ThemeColor(red: 0.73, green: 0.21, blue: 0.27),
                    border: ThemeColor(red: 0.90, green: 0.46, blue: 0.52)
                ),
                neutral: .init(
                    background: ThemeColor(red: 0.88, green: 0.94, blue: 1.00),
                    foreground: ThemeColor(red: 0.31, green: 0.45, blue: 0.62),
                    border: ThemeColor(red: 0.60, green: 0.75, blue: 0.92)
                )
            )
        case .olive:
            return AuraTheme(
                overlay: .init(
                    radialInner: ThemeColor(red: 0.72, green: 0.80, blue: 0.42),
                    radialMiddle: ThemeColor(red: 0.55, green: 0.66, blue: 0.28),
                    radialOuter: ThemeColor(red: 0.55, green: 0.66, blue: 0.28),
                    baseInner: ThemeColor(red: 0.79, green: 0.86, blue: 0.53),
                    baseOuter: ThemeColor(red: 0.41, green: 0.50, blue: 0.19),
                    shadow: ThemeColor(red: 0.64, green: 0.73, blue: 0.34)
                ),
                accentStrong: ThemeColor(red: 0.42, green: 0.52, blue: 0.20),
                accentText: ThemeColor(red: 0.22, green: 0.28, blue: 0.11),
                accentSoft: ThemeColor(red: 0.94, green: 0.97, blue: 0.84),
                accentMuted: ThemeColor(red: 0.79, green: 0.86, blue: 0.53),
                accentBorder: ThemeColor(red: 0.61, green: 0.72, blue: 0.31),
                shadow: ThemeColor(red: 0.64, green: 0.73, blue: 0.34),
                warning: .init(
                    background: ThemeColor(red: 0.95, green: 0.97, blue: 0.84),
                    foreground: ThemeColor(red: 0.31, green: 0.38, blue: 0.12),
                    border: ThemeColor(red: 0.75, green: 0.82, blue: 0.42)
                ),
                success: .init(
                    background: ThemeColor(red: 0.88, green: 0.95, blue: 0.86),
                    foreground: ThemeColor(red: 0.19, green: 0.47, blue: 0.25),
                    border: ThemeColor(red: 0.48, green: 0.73, blue: 0.51)
                ),
                error: .init(
                    background: ThemeColor(red: 0.98, green: 0.90, blue: 0.85),
                    foreground: ThemeColor(red: 0.67, green: 0.25, blue: 0.19),
                    border: ThemeColor(red: 0.86, green: 0.52, blue: 0.37)
                ),
                neutral: .init(
                    background: ThemeColor(red: 0.92, green: 0.95, blue: 0.84),
                    foreground: ThemeColor(red: 0.37, green: 0.43, blue: 0.18),
                    border: ThemeColor(red: 0.68, green: 0.76, blue: 0.40)
                )
            )
        case .magenta:
            return AuraTheme(
                overlay: .init(
                    radialInner: ThemeColor(red: 0.97, green: 0.50, blue: 0.86),
                    radialMiddle: ThemeColor(red: 0.82, green: 0.31, blue: 0.68),
                    radialOuter: ThemeColor(red: 0.82, green: 0.31, blue: 0.68),
                    baseInner: ThemeColor(red: 0.98, green: 0.66, blue: 0.92),
                    baseOuter: ThemeColor(red: 0.67, green: 0.20, blue: 0.55),
                    shadow: ThemeColor(red: 0.90, green: 0.42, blue: 0.78)
                ),
                accentStrong: ThemeColor(red: 0.76, green: 0.24, blue: 0.63),
                accentText: ThemeColor(red: 0.43, green: 0.17, blue: 0.37),
                accentSoft: ThemeColor(red: 0.99, green: 0.91, blue: 0.97),
                accentMuted: ThemeColor(red: 0.95, green: 0.69, blue: 0.91),
                accentBorder: ThemeColor(red: 0.86, green: 0.44, blue: 0.74),
                shadow: ThemeColor(red: 0.90, green: 0.42, blue: 0.78),
                warning: .init(
                    background: ThemeColor(red: 0.98, green: 0.91, blue: 0.97),
                    foreground: ThemeColor(red: 0.49, green: 0.20, blue: 0.42),
                    border: ThemeColor(red: 0.92, green: 0.63, blue: 0.85)
                ),
                success: .init(
                    background: ThemeColor(red: 0.89, green: 0.95, blue: 0.93),
                    foreground: ThemeColor(red: 0.18, green: 0.48, blue: 0.37),
                    border: ThemeColor(red: 0.48, green: 0.76, blue: 0.63)
                ),
                error: .init(
                    background: ThemeColor(red: 1.00, green: 0.89, blue: 0.92),
                    foreground: ThemeColor(red: 0.74, green: 0.19, blue: 0.36),
                    border: ThemeColor(red: 0.92, green: 0.45, blue: 0.59)
                ),
                neutral: .init(
                    background: ThemeColor(red: 0.97, green: 0.90, blue: 0.96),
                    foreground: ThemeColor(red: 0.48, green: 0.25, blue: 0.44),
                    border: ThemeColor(red: 0.83, green: 0.56, blue: 0.78)
                )
            )
        case .sand:
            return AuraTheme(
                overlay: .init(
                    radialInner: ThemeColor(red: 0.96, green: 0.76, blue: 0.53),
                    radialMiddle: ThemeColor(red: 0.85, green: 0.61, blue: 0.34),
                    radialOuter: ThemeColor(red: 0.85, green: 0.61, blue: 0.34),
                    baseInner: ThemeColor(red: 0.98, green: 0.84, blue: 0.64),
                    baseOuter: ThemeColor(red: 0.73, green: 0.47, blue: 0.21),
                    shadow: ThemeColor(red: 0.90, green: 0.69, blue: 0.44)
                ),
                accentStrong: ThemeColor(red: 0.76, green: 0.49, blue: 0.23),
                accentText: ThemeColor(red: 0.43, green: 0.28, blue: 0.14),
                accentSoft: ThemeColor(red: 1.00, green: 0.95, blue: 0.89),
                accentMuted: ThemeColor(red: 0.97, green: 0.84, blue: 0.64),
                accentBorder: ThemeColor(red: 0.86, green: 0.63, blue: 0.36),
                shadow: ThemeColor(red: 0.90, green: 0.69, blue: 0.44),
                warning: .init(
                    background: ThemeColor(red: 1.00, green: 0.95, blue: 0.88),
                    foreground: ThemeColor(red: 0.49, green: 0.32, blue: 0.17),
                    border: ThemeColor(red: 0.94, green: 0.76, blue: 0.53)
                ),
                success: .init(
                    background: ThemeColor(red: 0.90, green: 0.95, blue: 0.89),
                    foreground: ThemeColor(red: 0.22, green: 0.47, blue: 0.24),
                    border: ThemeColor(red: 0.51, green: 0.75, blue: 0.49)
                ),
                error: .init(
                    background: ThemeColor(red: 1.00, green: 0.90, blue: 0.86),
                    foreground: ThemeColor(red: 0.72, green: 0.28, blue: 0.20),
                    border: ThemeColor(red: 0.90, green: 0.55, blue: 0.42)
                ),
                neutral: .init(
                    background: ThemeColor(red: 0.98, green: 0.93, blue: 0.86),
                    foreground: ThemeColor(red: 0.49, green: 0.34, blue: 0.20),
                    border: ThemeColor(red: 0.86, green: 0.69, blue: 0.47)
                )
            )
        case .slate:
            return AuraTheme(
                overlay: .init(
                    radialInner: ThemeColor(red: 0.73, green: 0.74, blue: 0.77),
                    radialMiddle: ThemeColor(red: 0.56, green: 0.58, blue: 0.61),
                    radialOuter: ThemeColor(red: 0.56, green: 0.58, blue: 0.61),
                    baseInner: ThemeColor(red: 0.82, green: 0.83, blue: 0.86),
                    baseOuter: ThemeColor(red: 0.39, green: 0.40, blue: 0.43),
                    shadow: ThemeColor(red: 0.63, green: 0.64, blue: 0.68)
                ),
                accentStrong: ThemeColor(red: 0.36, green: 0.37, blue: 0.40),
                accentText: ThemeColor(red: 0.24, green: 0.25, blue: 0.28),
                accentSoft: ThemeColor(red: 0.93, green: 0.93, blue: 0.95),
                accentMuted: ThemeColor(red: 0.81, green: 0.82, blue: 0.85),
                accentBorder: ThemeColor(red: 0.60, green: 0.61, blue: 0.65),
                shadow: ThemeColor(red: 0.55, green: 0.56, blue: 0.60),
                warning: .init(
                    background: ThemeColor(red: 0.94, green: 0.94, blue: 0.96),
                    foreground: ThemeColor(red: 0.31, green: 0.32, blue: 0.36),
                    border: ThemeColor(red: 0.72, green: 0.73, blue: 0.77)
                ),
                success: .init(
                    background: ThemeColor(red: 0.89, green: 0.95, blue: 0.92),
                    foreground: ThemeColor(red: 0.20, green: 0.47, blue: 0.33),
                    border: ThemeColor(red: 0.49, green: 0.76, blue: 0.58)
                ),
                error: .init(
                    background: ThemeColor(red: 0.99, green: 0.90, blue: 0.91),
                    foreground: ThemeColor(red: 0.70, green: 0.23, blue: 0.30),
                    border: ThemeColor(red: 0.88, green: 0.50, blue: 0.56)
                ),
                neutral: .init(
                    background: ThemeColor(red: 0.93, green: 0.93, blue: 0.95),
                    foreground: ThemeColor(red: 0.36, green: 0.37, blue: 0.40),
                    border: ThemeColor(red: 0.68, green: 0.69, blue: 0.73)
                )
            )
        }
    }
}
