import Foundation

protocol TranscriptionEngine: Sendable {
    func prepare(configuration: TranscriptionConfiguration) async throws
    func transcribe(audioURL: URL, configuration: TranscriptionConfiguration) async throws -> String
    func teardownIfIdle(after seconds: TimeInterval) async throws
}

actor WhisperCLITranscriptionEngine: TranscriptionEngine {
    private var lastUseDate: Date?

    func prepare(configuration: TranscriptionConfiguration) async throws {
        let binaryPath = NSString(string: configuration.whisperBinaryPath).expandingTildeInPath
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw WhisperEngineError.binaryNotFound(binaryPath)
        }

        let modelPath = NSString(string: configuration.modelPath).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperEngineError.modelNotFound(modelPath)
        }
    }

    func transcribe(audioURL: URL, configuration: TranscriptionConfiguration) async throws -> String {
        let binaryPath = NSString(string: configuration.whisperBinaryPath).expandingTildeInPath
        let modelPath = NSString(string: configuration.modelPath).expandingTildeInPath
        let outputBase = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "-m", modelPath,
            "-f", audioURL.path,
            "-otxt",
            "-of", outputBase.path,
            "-np"
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let stderr = String(data: stderrData, encoding: .utf8) ?? "Unknown whisper.cpp failure"
            throw WhisperEngineError.transcriptionFailed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let transcriptURL = outputBase.appendingPathExtension("txt")
        let transcript = try String(contentsOf: transcriptURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        lastUseDate = Date()
        return transcript
    }

    func teardownIfIdle(after seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(for: .seconds(seconds))
        guard let lastUseDate else { return }
        if Date().timeIntervalSince(lastUseDate) >= seconds {
            self.lastUseDate = nil
        }
    }
}

enum WhisperEngineError: LocalizedError {
    case binaryNotFound(String)
    case modelNotFound(String)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "whisper-cli was not found at \(path)."
        case .modelNotFound(let path):
            return "Whisper model file was not found at \(path)."
        case .transcriptionFailed(let message):
            return "whisper.cpp failed: \(message)"
        }
    }
}
