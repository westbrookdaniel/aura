import Testing
@testable import Listener

struct ShortcutSpecTests {
    @Test
    func defaultShortcutUsesFn() {
        #expect(ShortcutSpec.default.triggerKey == .fn)
        #expect(ShortcutSpec.default.modifiers.isEmpty)
    }

    @Test
    func displayNameIncludesModifiers() {
        let shortcut = ShortcutSpec(
            triggerKey: .space,
            modifiers: [.control, .option],
            customCharacter: nil
        )

        #expect(shortcut.displayName == "Control + Option + Space")
    }
}
