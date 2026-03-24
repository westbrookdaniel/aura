import Testing
@testable import Listener

struct ShortcutSpecTests {
    @Test
    func defaultShortcutUsesFn() {
        #expect(ShortcutSpec.default.triggerKey == .optionFn)
        #expect(ShortcutSpec.default.modifiers.isEmpty)
    }

    @Test
    func displayNameIncludesModifiers() {
        let shortcut = ShortcutSpec(
            triggerKey: .customShortcut,
            modifiers: [.control, .option],
            keyCode: 40,
            keyDisplay: "K"
        )

        #expect(shortcut.displayName == "Control + Option + K")
    }
}
