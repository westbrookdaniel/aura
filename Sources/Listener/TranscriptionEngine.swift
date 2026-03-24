import Foundation

protocol TranscriptionEngine: Sendable {
    func prepare(configuration: TranscriptionConfiguration) async throws
    func transcribe(audioURL: URL, configuration: TranscriptionConfiguration) async throws -> TranscriptionResult
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

    func transcribe(audioURL: URL, configuration: TranscriptionConfiguration) async throws -> TranscriptionResult {
        let binaryPath = NSString(string: configuration.whisperBinaryPath).expandingTildeInPath
        let modelPath = NSString(string: configuration.modelPath).expandingTildeInPath
        let outputDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let outputBase = outputDirectory.appendingPathComponent("transcript")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        var arguments = [
            "-m", modelPath,
            "-f", audioURL.path,
            "-bs", String(configuration.beamSize),
            "-bo", String(configuration.bestOf),
            "-nth", String(configuration.noSpeechThreshold),
            "-otxt",
            "-of", outputBase.path,
            "-np"
        ]
        if configuration.promptTerms.isEmpty == false {
            arguments.append(contentsOf: ["--prompt", configuration.promptTerms.joined(separator: ", ")])
        }
        process.arguments = arguments

        let errorPipe = Pipe()
        let outputPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let stderr = String(data: stderrData, encoding: .utf8) ?? "Unknown whisper.cpp failure"
            throw WhisperEngineError.transcriptionFailed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let transcriptURL = outputBase.appendingPathExtension("txt")
        let transcript: String
        if FileManager.default.fileExists(atPath: transcriptURL.path) {
            transcript = try String(contentsOf: transcriptURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let stdoutText = String(data: stdoutData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
                  !stdoutText.isEmpty {
            transcript = stdoutText
        } else {
            let stderr = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "No transcript file was produced."
            throw WhisperEngineError.transcriptionOutputMissing(stderr)
        }

        lastUseDate = Date()
        return TranscriptionResult(text: transcript, analysis: nil)
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
    case transcriptionOutputMissing(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "whisper-cli was not found at \(path)."
        case .modelNotFound(let path):
            return "Whisper model file was not found at \(path)."
        case .transcriptionFailed(let message):
            return "whisper.cpp failed: \(message)"
        case .transcriptionOutputMissing(let message):
            return "whisper.cpp finished but did not produce readable output: \(message)"
        }
    }
}
