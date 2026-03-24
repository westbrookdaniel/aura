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

    var transcriptionConfiguration: TranscriptionConfiguration {
        TranscriptionConfiguration(
            whisperBinaryPath: whisperBinaryPath,
            modelPath: modelPath
        )
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let shortcut = "shortcut"
        static let whisperBinaryPath = "whisperBinaryPath"
        static let soxBinaryPath = "soxBinaryPath"
        static let modelPath = "modelPath"
        static let selectedMicrophoneID = "selectedMicrophoneID"
    }

    private init() {
        shortcut = Self.decode(Keys.shortcut) ?? .default
        whisperBinaryPath = defaults.string(forKey: Keys.whisperBinaryPath) ?? "/opt/homebrew/bin/whisper-cli"
        soxBinaryPath = defaults.string(forKey: Keys.soxBinaryPath) ?? "/opt/homebrew/bin/sox"
        modelPath = defaults.string(forKey: Keys.modelPath) ?? WhisperInstallService.expectedModelPath()
        if defaults.object(forKey: Keys.selectedMicrophoneID) != nil {
            selectedMicrophoneID = UInt32(defaults.integer(forKey: Keys.selectedMicrophoneID))
        } else {
            selectedMicrophoneID = nil
        }
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
