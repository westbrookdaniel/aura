import Combine
import Foundation

@MainActor
final class AppPreferencesStore: ObservableObject {
    static let shared = AppPreferencesStore()

    @Published var shortcut: ShortcutSpec {
        didSet { save(shortcut, key: Keys.shortcut) }
    }

    @Published var whisperBinaryPath: String {
        didSet { defaults.set(whisperBinaryPath, forKey: Keys.whisperBinaryPath) }
    }

    @Published var soxBinaryPath: String {
        didSet { defaults.set(soxBinaryPath, forKey: Keys.soxBinaryPath) }
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

    var transcriptionConfiguration: TranscriptionConfiguration {
        TranscriptionConfiguration(
            whisperBinaryPath: whisperBinaryPath,
            modelPath: modelPath
        )
    }

    private let defaults = UserDefaults.standard
    private static let legacyBaseModelFilename = "ggml-base.en.bin"

    private enum Keys {
        static let shortcut = "shortcut"
        static let whisperBinaryPath = "whisperBinaryPath"
        static let soxBinaryPath = "soxBinaryPath"
        static let modelPath = "modelPath"
        static let selectedMicrophoneID = "selectedMicrophoneID"
        static let voiceTextHistory = "voiceTextHistory"
    }

    private static let maxVoiceTextHistoryCount = 200

    private init() {
        shortcut = Self.decode(Keys.shortcut) ?? .default
        whisperBinaryPath = defaults.string(forKey: Keys.whisperBinaryPath) ?? "/opt/homebrew/bin/whisper-cli"
        soxBinaryPath = defaults.string(forKey: Keys.soxBinaryPath) ?? "/opt/homebrew/bin/sox"
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

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
