import Foundation

enum InstallProgressState: Equatable {
    case idle
    case working(String)
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .idle:
            return ""
        case .working(let message), .success(let message), .failure(let message):
            return message
        }
    }
}

enum WhisperInstallService {
    static let mediumEnglishFilename = "ggml-medium.en.bin"

    static func installCLI() async throws -> String {
        let brewPath = try resolveBrewPath()
        try await runProcess(executable: brewPath, arguments: ["install", "whisper-cpp"])

        let prefix = try await captureProcessOutput(executable: brewPath, arguments: ["--prefix", "whisper-cpp"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = URL(fileURLWithPath: prefix).appendingPathComponent("bin/whisper-cli").path

        if FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        let fallbackPaths = [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli"
        ]

        if let fallback = fallbackPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fallback
        }

        throw WhisperInstallError.cliNotFoundAfterInstall
    }

    static func downloadBaseModel() async throws -> String {
        let destination = try modelDestinationURL()
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let (temporaryURL, _) = try await URLSession.shared.download(from: downloadURL)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination.path
    }

    static func expectedModelPath() -> String {
        (try? modelDestinationURL().path) ?? ""
    }

    static func installSox() async throws -> String {
        let brewPath = try resolveBrewPath()
        try await runProcess(executable: brewPath, arguments: ["install", "sox"])

        let prefix = try await captureProcessOutput(executable: brewPath, arguments: ["--prefix", "sox"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = URL(fileURLWithPath: prefix).appendingPathComponent("bin/sox").path

        if FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        let fallbackPaths = [
            "/opt/homebrew/bin/sox",
            "/usr/local/bin/sox"
        ]

        if let fallback = fallbackPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fallback
        }

        throw WhisperInstallError.soxNotFoundAfterInstall
    }

    static func isCLIInstalled(at path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: NSString(string: path).expandingTildeInPath)
    }

    static func isBaseModelInstalled(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: NSString(string: path).expandingTildeInPath)
    }

    static func isSoxInstalled(at path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: NSString(string: path).expandingTildeInPath)
    }

    private static func modelDestinationURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Listener", isDirectory: true)
        return appSupport.appendingPathComponent(mediumEnglishFilename)
    }

    private static var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(mediumEnglishFilename)?download=true")!
    }

    private static func resolveBrewPath() throws -> String {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]

        if let match = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return match
        }

        throw WhisperInstallError.homebrewNotFound
    }

    private static func runProcess(executable: String, arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw WhisperInstallError.installFailed(error?.isEmpty == false ? error! : "Unknown install failure")
        }
    }

    private static func captureProcessOutput(executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw WhisperInstallError.installFailed(error?.isEmpty == false ? error! : "Unknown install failure")
        }

        return String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

enum WhisperInstallError: LocalizedError {
    case homebrewNotFound
    case cliNotFoundAfterInstall
    case soxNotFoundAfterInstall
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .homebrewNotFound:
            return "Homebrew was not found. Install Homebrew first, then try again."
        case .cliNotFoundAfterInstall:
            return "whisper-cpp installed, but Listener could not find whisper-cli afterwards."
        case .soxNotFoundAfterInstall:
            return "SoX installed, but Listener could not find the `sox` binary afterwards."
        case .installFailed(let message):
            return "Whisper install failed: \(message)"
        }
    }
}
