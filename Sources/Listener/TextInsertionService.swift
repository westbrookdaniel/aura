import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

protocol TextInsertionService {
    func insert(text: String, fallbackPolicy: TextInsertionFallbackPolicy) throws -> TextInsertionResult
}

struct AccessibilityTextInsertionService: TextInsertionService {
    func insert(text: String, fallbackPolicy: TextInsertionFallbackPolicy) throws -> TextInsertionResult {
        if try insertViaAccessibility(text: text) {
            return .accessibility
        }

        guard fallbackPolicy == .accessibilityThenPaste else {
            return .failed("The focused field does not support direct accessibility insertion.")
        }

        try insertViaPaste(text: text)
        return .pasteFallback
    }

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

    private func replaceCharacters(in source: String, selectedRange: NSRange, with replacement: String) -> String {
        guard let swiftRange = Range(selectedRange, in: source) else {
            return source + replacement
        }
        return source.replacingCharacters(in: swiftRange, with: replacement)
    }

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

    private func insertViaPaste(text: String) throws {
        let pasteboard = NSPasteboard.general
        let priorItems = pasteboard.pasteboardItems
        let previousChangeCount = pasteboard.changeCount

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        defer {
            pasteboard.clearContents()
            if let priorItems {
                for item in priorItems {
                    pasteboard.writeObjects([item])
                }
            }
            if pasteboard.changeCount == previousChangeCount + 1 {
                pasteboard.clearContents()
            }
        }

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw TextInsertionError.couldNotCreateEventSource
        }

        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false)
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        commandDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        commandUp?.post(tap: .cghidEventTap)
    }
}

enum TextInsertionError: LocalizedError {
    case secureField
    case couldNotCreateEventSource

    var errorDescription: String? {
        switch self {
        case .secureField:
            return "WhisperBar will not insert text into secure fields."
        case .couldNotCreateEventSource:
            return "Could not create the key event source for paste fallback."
        }
    }
}
