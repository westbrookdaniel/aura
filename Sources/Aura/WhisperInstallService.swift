import Foundation

enum InstallProgressState: Equatable {
    case idle
    case working(message: String, progress: Double?)
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .idle:
            return ""
        case .working(let message, _), .success(let message), .failure(let message):
            return message
        }
    }

    var progress: Double? {
        switch self {
        case .working(_, let progress):
            return progress
        case .idle, .success, .failure:
            return nil
        }
    }
}

enum WhisperInstallService {
    static let mediumEnglishFilename = "ggml-medium.en.bin"

    static func installCLI(onStageChange: @escaping @Sendable (String) -> Void = { _ in }) async throws -> String {
        onStageChange("Installing whisper.cpp with Homebrew...")
        let brewPath = try resolveBrewPath()
        try await runProcess(executable: brewPath, arguments: ["install", "whisper-cpp"])

        onStageChange("Verifying whisper.cpp install...")
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

    static func downloadBaseModel(onProgress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> String {
        let destination = try modelDestinationURL()
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let temporaryURL = try await downloadFile(from: downloadURL, onProgress: onProgress)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination.path
    }

    static func expectedModelPath() -> String {
        (try? modelDestinationURL().path) ?? ""
    }

    static func installSox(onStageChange: @escaping @Sendable (String) -> Void = { _ in }) async throws -> String {
        onStageChange("Installing SoX with Homebrew...")
        let brewPath = try resolveBrewPath()
        try await runProcess(executable: brewPath, arguments: ["install", "sox"])

        onStageChange("Verifying SoX install...")
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
        ).appendingPathComponent("Aura", isDirectory: true)
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

    private static func downloadFile(from url: URL, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let delegate = DownloadDelegate(onProgress: onProgress)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        return try await delegate.download(with: session, from: url)
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var lastReportedProgress: Double = 0

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func download(with session: URLSession, from url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let persistedLocation = FileManager.default.temporaryDirectory
                .appendingPathComponent("aura-model-download-\(UUID().uuidString).tmp")
            if FileManager.default.fileExists(atPath: persistedLocation.path) {
                try FileManager.default.removeItem(at: persistedLocation)
            }
            try FileManager.default.moveItem(at: location, to: persistedLocation)
            continuation?.resume(returning: persistedLocation)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0), 1)
        guard progress - lastReportedProgress >= 0.01 || progress >= 1 else { return }
        lastReportedProgress = progress
        onProgress(progress)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        continuation?.resume(throwing: error)
        continuation = nil
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
            return "whisper-cpp installed, but Aura could not find whisper-cli afterwards."
        case .soxNotFoundAfterInstall:
            return "SoX installed, but Aura could not find the `sox` binary afterwards."
        case .installFailed(let message):
            return "Whisper install failed: \(message)"
        }
    }
}
