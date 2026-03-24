import Combine
import Foundation

@MainActor
final class AppPreferencesStore: ObservableObject {
    static let shared = AppPreferencesStore()

    @Published var shortcut: ShortcutSpec {
        didSet { save(shortcut, key: Keys.shortcut) }
    }

    @Published var modelSelection: WhisperModelSelection {
        didSet { save(modelSelection, key: Keys.modelSelection) }
    }

    @Published var workerIdleTimeout: TimeInterval {
        didSet { defaults.set(workerIdleTimeout, forKey: Keys.workerIdleTimeout) }
    }

    @Published var whisperBinaryPath: String {
        didSet { defaults.set(whisperBinaryPath, forKey: Keys.whisperBinaryPath) }
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
            modelPath: modelPath,
            modelSelection: modelSelection,
            preprocessing: AudioPreprocessingConfiguration(),
            promptTerms: [],
            noSpeechThreshold: 0.70,
            beamSize: 9,
            bestOf: 9
        )
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let shortcut = "shortcut"
        static let modelSelection = "modelSelection"
        static let workerIdleTimeout = "workerIdleTimeout"
        static let whisperBinaryPath = "whisperBinaryPath"
        static let modelPath = "modelPath"
        static let selectedMicrophoneID = "selectedMicrophoneID"
    }

    private init() {
        shortcut = Self.decode(Keys.shortcut) ?? .default
        modelSelection = .baseEn
        workerIdleTimeout = defaults.object(forKey: Keys.workerIdleTimeout) as? TimeInterval ?? 120
        whisperBinaryPath = defaults.string(forKey: Keys.whisperBinaryPath) ?? "/opt/homebrew/bin/whisper-cli"
        modelPath = defaults.string(forKey: Keys.modelPath) ?? "~/Library/Application Support/Listener/\(WhisperModelSelection.baseEn.suggestedFilename)"
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
