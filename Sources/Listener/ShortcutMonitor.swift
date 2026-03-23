import AppKit
import Carbon.HIToolbox
import Cocoa
import Foundation

@MainActor
final class ShortcutMonitor {
    private var currentShortcut: ShortcutSpec = .default
    private var localMonitors: [Any] = []
    private var globalMonitors: [Any] = []
    private var onPress: (() -> Void)?
    private var onRelease: (() -> Void)?
    private var isPressed = false

    func start(shortcut: ShortcutSpec, onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        stop()
        currentShortcut = shortcut
        self.onPress = onPress
        self.onRelease = onRelease
        installMonitors()
    }

    func stop() {
        localMonitors.forEach(NSEvent.removeMonitor)
        globalMonitors.forEach(NSEvent.removeMonitor)
        localMonitors.removeAll()
        globalMonitors.removeAll()
        isPressed = false
    }

    func updateShortcut(_ shortcut: ShortcutSpec) {
        currentShortcut = shortcut
    }

    private func installMonitors() {
        let eventTypes: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]

        localMonitors.append(NSEvent.addLocalMonitorForEvents(matching: eventTypes) { [weak self] event in
            self?.handle(event)
            return event
        } as Any)

        globalMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: eventTypes) { [weak self] event in
            self?.handle(event)
        } as Any)
    }

    private func handle(_ event: NSEvent) {
        let matches = eventMatchesShortcut(event)

        switch event.type {
        case .flagsChanged, .keyDown:
            if matches && !isPressed {
                isPressed = true
                onPress?()
            } else if !matches && isPressed && currentShortcut.triggerKey == .fn {
                isPressed = false
                onRelease?()
            }
        case .keyUp:
            if isPressed && matches {
                isPressed = false
                onRelease?()
            }
        default:
            break
        }
    }

    private func eventMatchesShortcut(_ event: NSEvent) -> Bool {
        let modifiers = EventModifiers(nsFlags: event.modifierFlags, removingTriggerFor: currentShortcut.triggerKey)
        guard modifiers == currentShortcut.modifiers else {
            return false
        }

        switch currentShortcut.triggerKey {
        case .fn:
            return event.modifierFlags.contains(.function)
        case .rightCommand:
            return event.keyCode == UInt16(kVK_RightCommand)
        case .rightOption:
            return event.keyCode == UInt16(kVK_RightOption)
        case .space:
            return event.keyCode == UInt16(kVK_Space)
        case .grave:
            return event.keyCode == UInt16(kVK_ANSI_Grave)
        case .customCharacter:
            guard let characters = event.charactersIgnoringModifiers?.lowercased(),
                  let customCharacter = currentShortcut.customCharacter?.lowercased()
            else {
                return false
            }
            return characters == customCharacter
        }
    }
}

private extension EventModifiers {
    init(nsFlags: NSEvent.ModifierFlags, removingTriggerFor trigger: ShortcutSpec.TriggerKey) {
        var value: EventModifiers = []
        if nsFlags.contains(.command), trigger != .rightCommand { value.insert(.command) }
        if nsFlags.contains(.option), trigger != .rightOption { value.insert(.option) }
        if nsFlags.contains(.control) { value.insert(.control) }
        if nsFlags.contains(.shift) { value.insert(.shift) }
        self = value
    }
}
