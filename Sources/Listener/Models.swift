import Foundation

enum RecordingSessionState: Equatable {
    case idle
    case recording
    case transcribing
    case inserting
    case error(String)

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .recording:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .inserting:
            return "Inserting"
        case .error:
            return "Error"
        }
    }
}

enum PermissionAuthorization: String, Codable {
    case granted
    case denied
    case notDetermined
}

struct PermissionState: Equatable {
    var microphone: PermissionAuthorization
    var accessibility: PermissionAuthorization
    var inputMonitoring: PermissionAuthorization

    static let unknown = PermissionState(
        microphone: .notDetermined,
        accessibility: .notDetermined,
        inputMonitoring: .notDetermined
    )
}

enum TextInsertionFallbackPolicy: String, CaseIterable, Codable, Identifiable {
    case accessibilityOnly
    case accessibilityThenPaste

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .accessibilityOnly:
            return "Accessibility only"
        case .accessibilityThenPaste:
            return "Accessibility + paste fallback"
        }
    }
}

enum WhisperModelSelection: String, CaseIterable, Codable, Identifiable {
    case baseEn
    case smallEn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .baseEn:
            return "Base English"
        case .smallEn:
            return "Small English"
        }
    }

    var suggestedFilename: String {
        switch self {
        case .baseEn:
            return "ggml-base.en.bin"
        case .smallEn:
            return "ggml-small.en.bin"
        }
    }
}

struct ShortcutSpec: Equatable, Codable {
    enum TriggerKey: String, CaseIterable, Codable, Identifiable {
        case fn
        case rightCommand
        case rightOption
        case space
        case grave
        case customCharacter

        var id: String { rawValue }
    }

    var triggerKey: TriggerKey
    var modifiers: EventModifiers
    var customCharacter: String?

    static let `default` = ShortcutSpec(triggerKey: .fn, modifiers: [], customCharacter: nil)

    var displayName: String {
        let prefix = modifiers.displayName
        let keyName: String
        switch triggerKey {
        case .fn:
            keyName = "Fn"
        case .rightCommand:
            keyName = "Right Command"
        case .rightOption:
            keyName = "Right Option"
        case .space:
            keyName = "Space"
        case .grave:
            keyName = "`"
        case .customCharacter:
            keyName = customCharacter?.uppercased() ?? "Custom"
        }

        if prefix.isEmpty {
            return keyName
        }
        return "\(prefix) + \(keyName)"
    }
}

struct EventModifiers: OptionSet, Codable, Equatable {
    let rawValue: Int

    static let command = EventModifiers(rawValue: 1 << 0)
    static let option = EventModifiers(rawValue: 1 << 1)
    static let control = EventModifiers(rawValue: 1 << 2)
    static let shift = EventModifiers(rawValue: 1 << 3)

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    var displayName: String {
        var parts: [String] = []
        if contains(.control) { parts.append("Control") }
        if contains(.option) { parts.append("Option") }
        if contains(.shift) { parts.append("Shift") }
        if contains(.command) { parts.append("Command") }
        return parts.joined(separator: " + ")
    }
}

struct TranscriptionConfiguration: Equatable {
    var whisperBinaryPath: String
    var modelPath: String
    var modelSelection: WhisperModelSelection
}

enum TextInsertionResult: Equatable {
    case accessibility
    case pasteFallback
    case failed(String)
}
