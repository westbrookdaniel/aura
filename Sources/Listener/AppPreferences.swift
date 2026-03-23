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

    @Published var fallbackPolicy: TextInsertionFallbackPolicy {
        didSet { save(fallbackPolicy, key: Keys.fallbackPolicy) }
    }

    @Published var whisperBinaryPath: String {
        didSet { defaults.set(whisperBinaryPath, forKey: Keys.whisperBinaryPath) }
    }

    @Published var modelPath: String {
        didSet { defaults.set(modelPath, forKey: Keys.modelPath) }
    }

    var transcriptionConfiguration: TranscriptionConfiguration {
        TranscriptionConfiguration(
            whisperBinaryPath: whisperBinaryPath,
            modelPath: modelPath,
            modelSelection: modelSelection
        )
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let shortcut = "shortcut"
        static let modelSelection = "modelSelection"
        static let workerIdleTimeout = "workerIdleTimeout"
        static let fallbackPolicy = "fallbackPolicy"
        static let whisperBinaryPath = "whisperBinaryPath"
        static let modelPath = "modelPath"
    }

    private init() {
        shortcut = Self.decode(Keys.shortcut) ?? .default
        modelSelection = Self.decode(Keys.modelSelection) ?? .baseEn
        workerIdleTimeout = defaults.object(forKey: Keys.workerIdleTimeout) as? TimeInterval ?? 120
        fallbackPolicy = Self.decode(Keys.fallbackPolicy) ?? .accessibilityThenPaste
        whisperBinaryPath = defaults.string(forKey: Keys.whisperBinaryPath) ?? "/opt/homebrew/bin/whisper-cli"
        modelPath = defaults.string(forKey: Keys.modelPath) ?? "~/Library/Application Support/Listener/\(WhisperModelSelection.baseEn.suggestedFilename)"
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
