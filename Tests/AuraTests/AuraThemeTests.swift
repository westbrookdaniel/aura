import Testing
@testable import Aura

struct AuraThemeTests {
    @Test
    func everyAuraColorProducesCompleteThemeTokens() {
        for option in AuraColorOption.allCases {
            let theme = option.theme

            #expect(theme.overlay.baseInner != theme.overlay.baseOuter)
            #expect(theme.accentStrong != theme.accentSoft)
            #expect(theme.accentBorder != theme.shadow)
            #expect(theme.warning.foreground != theme.warning.background)
            #expect(theme.success.foreground != theme.error.foreground)
            #expect(theme.neutral.border != theme.neutral.background)
        }
    }

    @Test
    func slateThemeUsesSlateTokensForSharedSettingsAccents() {
        let theme = AuraColorOption.slate.theme

        #expect(theme.accentStrong == ThemeColor(red: 0.36, green: 0.37, blue: 0.40))
        #expect(theme.accentText == ThemeColor(red: 0.24, green: 0.25, blue: 0.28))
        #expect(theme.warning.border == ThemeColor(red: 0.72, green: 0.73, blue: 0.77))
        #expect(theme.neutral.foreground == ThemeColor(red: 0.36, green: 0.37, blue: 0.40))
        #expect(theme.overlay.baseOuter == ThemeColor(red: 0.39, green: 0.40, blue: 0.43))
    }

    @Test
    func permissionBadgesFollowSelectedThemePalette() {
        let aquaTheme = AuraColorOption.aqua.theme
        let slateTheme = AuraColorOption.slate.theme

        #expect(aquaTheme.badgePalette(for: .granted) == aquaTheme.success)
        #expect(slateTheme.badgePalette(for: .granted) == slateTheme.success)
        #expect(aquaTheme.badgePalette(for: .granted).foreground != slateTheme.badgePalette(for: .granted).foreground)
    }
}
