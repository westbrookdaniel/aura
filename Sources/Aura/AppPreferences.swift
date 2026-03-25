import Combine
import Foundation

enum AuraColorOption: String, Codable, CaseIterable, Identifiable {
    case aqua
    case olive
    case magenta
    case sand
    case slate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .aqua:
            return "Aqua"
        case .olive:
            return "Olive"
        case .magenta:
            return "Magenta"
        case .sand:
            return "Sand"
        case .slate:
            return "Slate"
        }
    }
}

enum AppAppearanceOption: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return "Match System"
        case .light:
            return "Always Light"
        case .dark:
            return "Always Dark"
        }
    }
}

enum OrbAppearanceOption: String, Codable, CaseIterable, Identifiable {
    case inherit
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inherit:
            return "Inherit"
        case .light:
            return "Always Light"
        case .dark:
            return "Always Dark"
        }
    }
}

@MainActor
final class AppPreferencesStore: ObservableObject {
    static let shared = AppPreferencesStore()

    @Published var shortcut: ShortcutSpec {
        didSet { save(shortcut, key: Keys.shortcut) }
    }

    @Published var modelPath: String {
        didSet { defaults.set(modelPath, forKey: Keys.modelPath) }
    }

    @Published var selectedMicrophoneID: UInt32? {
        didSet {
            if let selectedMicrophoneID {
                defaults.set(Int(selectedMicrophoneID), forKey: Keys.selectedMicrophoneID)
            } else {
                defaults.removeObject(forKey: Keys.selectedMicrophoneID)
            }
        }
    }

    @Published var voiceTextHistory: [VoiceTextHistoryItem] {
        didSet { save(voiceTextHistory, key: Keys.voiceTextHistory) }
    }

    @Published var auraColor: AuraColorOption {
        didSet { save(auraColor, key: Keys.auraColor) }
    }

    @Published var appearance: AppAppearanceOption {
        didSet { save(appearance, key: Keys.appearance) }
    }

    @Published var orbAppearance: OrbAppearanceOption {
        didSet { save(orbAppearance, key: Keys.orbAppearance) }
    }

    var transcriptionConfiguration: TranscriptionConfiguration {
        TranscriptionConfiguration(
            modelPath: modelPath
        )
    }

    private let defaults = UserDefaults.standard
    private static let legacyBaseModelFilename = "ggml-base.en.bin"

    private enum Keys {
        static let shortcut = "shortcut"
        static let modelPath = "modelPath"
        static let selectedMicrophoneID = "selectedMicrophoneID"
        static let voiceTextHistory = "voiceTextHistory"
        static let auraColor = "auraColor"
        static let appearance = "appearance"
        static let orbAppearance = "orbAppearance"
    }

    private static let maxVoiceTextHistoryCount = 200

    private init() {
        shortcut = Self.decode(Keys.shortcut) ?? .default
        let expectedModelPath = WhisperInstallService.expectedModelPath()
        let storedModelPath = defaults.string(forKey: Keys.modelPath)
        if let storedModelPath,
           NSString(string: storedModelPath).lastPathComponent == Self.legacyBaseModelFilename {
            modelPath = expectedModelPath
        } else {
            modelPath = storedModelPath ?? expectedModelPath
        }
        if defaults.object(forKey: Keys.selectedMicrophoneID) != nil {
            selectedMicrophoneID = UInt32(defaults.integer(forKey: Keys.selectedMicrophoneID))
        } else {
            selectedMicrophoneID = nil
        }
        voiceTextHistory = Self.decode(Keys.voiceTextHistory) ?? []
        auraColor = Self.decode(Keys.auraColor) ?? .aqua
        appearance = Self.decode(Keys.appearance) ?? .system
        orbAppearance = Self.decode(Keys.orbAppearance) ?? .light
    }

    func addVoiceTextHistoryItem(_ item: VoiceTextHistoryItem) {
        voiceTextHistory.insert(item, at: 0)
        if voiceTextHistory.count > Self.maxVoiceTextHistoryCount {
            voiceTextHistory.removeLast(voiceTextHistory.count - Self.maxVoiceTextHistoryCount)
        }
    }

    func clearVoiceTextHistory() {
        voiceTextHistory = []
    }

    func removeVoiceTextHistoryItem(id: UUID) {
        voiceTextHistory.removeAll { $0.id == id }
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
