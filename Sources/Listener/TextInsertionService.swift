import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

protocol TextInsertionService {
    @MainActor
    func insert(text: String) throws -> TextInsertionResult
}

struct AccessibilityTextInsertionService: TextInsertionService {
    @MainActor
    func insert(text: String) throws -> TextInsertionResult {
        if try insertViaAccessibility(text: text) {
            return .accessibility
        }

        if insertViaTyping(text: text) {
            return .typingFallback
        }

        try insertViaPaste(text: text)
        return .pasteFallback
    }

    @MainActor
    private func insertViaAccessibility(text: String) throws -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedResult == .success, let focusedElement = focused else {
            return false
        }

        let element = focusedElement as! AXUIElement

        if isSecureElement(element) {
            throw TextInsertionError.secureField
        }

        var selectedTextRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedTextRange)
        var isSettable = DarwinBoolean(false)
        let settableResult = AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &isSettable
        )

        if rangeResult == .success,
           selectedTextRange != nil,
           settableResult == .success,
           isSettable.boolValue {
            let setResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
            return setResult == .success
        }

        var currentValue: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)
        guard valueResult == .success, let existing = currentValue as? String else {
            return false
        }

        let selectedRange = try selectedRange(for: element)
        let updated = replaceCharacters(in: existing, selectedRange: selectedRange, with: text)
        let setValueResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, updated as CFTypeRef)
        guard setValueResult == .success else { return false }

        let newLocation = selectedRange.location + text.count
        var range = CFRange(location: newLocation, length: 0)
        if let axRange = AXValueCreate(.cfRange, &range) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axRange)
        }

        return true
    }

    @MainActor
    private func selectedRange(for element: AXUIElement) throws -> NSRange {
        var selectedRange: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        guard result == .success,
              let value = selectedRange,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return NSRange(location: 0, length: 0)
        }

        var range = CFRange(location: 0, length: 0)
        AXValueGetValue(value as! AXValue, .cfRange, &range)
        return NSRange(location: range.location, length: range.length)
    }

    @MainActor
    private func replaceCharacters(in source: String, selectedRange: NSRange, with replacement: String) -> String {
        guard let swiftRange = Range(selectedRange, in: source) else {
            return source + replacement
        }
        return source.replacingCharacters(in: swiftRange, with: replacement)
    }

    @MainActor
    private func isSecureElement(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        if let role = roleValue as? String, role.lowercased().contains("secure") {
            return true
        }

        var subroleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue)
        if let subrole = subroleValue as? String, subrole.lowercased().contains("secure") {
            return true
        }

        return false
    }

    @MainActor
    private func insertViaTyping(text: String) -> Bool {
        guard text.isEmpty == false else {
            return true
        }

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return false
        }

        let utf16Text = Array(text.utf16)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else {
            return false
        }

        keyDown.keyboardSetUnicodeString(stringLength: utf16Text.count, unicodeString: utf16Text)
        keyUp.keyboardSetUnicodeString(stringLength: utf16Text.count, unicodeString: utf16Text)
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }

    @MainActor
    private func insertViaPaste(text: String) throws {
        let pasteboard = NSPasteboard.general
        let existingStrings = pasteboard.pasteboardItems?.compactMap {
            $0.string(forType: .string)
        } ?? []

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw TextInsertionError.couldNotWritePasteboard
        }

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw TextInsertionError.couldNotCreateEventSource
        }

        let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        vUp?.post(tap: .cgAnnotatedSessionEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let restorePasteboard = NSPasteboard.general
            restorePasteboard.clearContents()
            if existingStrings.isEmpty == false {
                restorePasteboard.writeObjects(existingStrings as [NSString])
            }
        }
    }

}

enum TextInsertionError: LocalizedError {
    case secureField
    case couldNotCreateEventSource
    case couldNotWritePasteboard

    var errorDescription: String? {
        switch self {
        case .secureField:
            return "Listener will not insert text into secure fields."
        case .couldNotCreateEventSource:
            return "Could not create the key event source for paste fallback."
        case .couldNotWritePasteboard:
            return "Could not write the dictated text to the pasteboard for fallback insertion."
        }
    }
}
