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
        if handleFunctionKeyEvent(event) {
            return
        }

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

    private func handleFunctionKeyEvent(_ event: NSEvent) -> Bool {
        guard event.type == .flagsChanged else {
            return false
        }

        guard currentShortcut.triggerKey == .fn else {
            return false
        }

        let modifiers = EventModifiers(nsFlags: event.modifierFlags, removingTriggerFor: currentShortcut.triggerKey)
        let isFunctionDown = event.modifierFlags.contains(.function)

        if isFunctionDown && modifiers == currentShortcut.modifiers {
            if !isPressed {
                isPressed = true
                onPress?()
            }
        } else if isPressed {
            isPressed = false
            onRelease?()
        }

        return true
    }

    private func eventMatchesShortcut(_ event: NSEvent) -> Bool {
        let modifiers = EventModifiers(nsFlags: event.modifierFlags, removingTriggerFor: currentShortcut.triggerKey)
        guard modifiers == currentShortcut.modifiers else {
            return false
        }

        switch currentShortcut.triggerKey {
        case .fn:
            return false
        case .rightCommand:
            return event.keyCode == UInt16(kVK_RightCommand)
        case .rightOption:
            return event.keyCode == UInt16(kVK_RightOption)
        case .customShortcut:
            guard let keyCode = currentShortcut.keyCode else {
                return false
            }
            return event.keyCode == keyCode
        }
    }
}
