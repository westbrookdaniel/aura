import AppKit
import Carbon.HIToolbox
import Foundation

protocol TextInsertionService {
    @MainActor
    func insert(text: String) throws -> TextInsertionResult
}

struct PasteTextInsertionService: TextInsertionService {
    @MainActor
    func insert(text: String) throws -> TextInsertionResult {
        try insertViaPaste(text: text)
        return .paste
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
    case couldNotCreateEventSource
    case couldNotWritePasteboard

    var errorDescription: String? {
        switch self {
        case .couldNotCreateEventSource:
            return "Could not create the key event source for paste insertion."
        case .couldNotWritePasteboard:
            return "Could not write the dictated text to the pasteboard for insertion."
        }
    }
}
