import Foundation

enum WhisperInstallService {
    static let mediumEnglishFilename = "ggml-medium.en.bin"

    static func prepareBaseModel(
        onStageChange: @escaping @Sendable (String) -> Void = { _ in },
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> String {
        if let synchronizedPath = try synchronizeModelLocationIfNeeded(onStageChange: onStageChange) {
            return synchronizedPath
        }

        onStageChange("Downloading Model (1.5 GB)")
        return try await downloadBaseModel(onProgress: onProgress)
    }

    static func downloadBaseModel(
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> String {
        let destination = try modelDestinationURL()
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let temporaryURL = try await downloadFile(from: downloadURL, onProgress: onProgress)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination.path
    }

    static func synchronizeModelLocationIfNeeded(
        onStageChange: @escaping @Sendable (String) -> Void = { _ in }
    ) throws -> String? {
        let destination = try modelDestinationURL()
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destination.path) {
            return destination.path
        }

        let legacy = try legacyModelURL()
        if FileManager.default.fileExists(atPath: legacy.path) {
            onStageChange("Moving existing model into cache...")
            try moveItemReplacingDestination(from: legacy, to: destination)
            return destination.path
        }

        return nil
    }

    static func expectedModelPath() -> String {
        (try? modelDestinationURL().path) ?? ""
    }

    static func isBaseModelInstalled(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: NSString(string: path).expandingTildeInPath)
    }

    private static func modelDestinationURL() throws -> URL {
        let cachesDirectory = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let modelDirectory = cachesDirectory
            .appendingPathComponent("Aura", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        return modelDirectory.appendingPathComponent(mediumEnglishFilename)
    }

    private static func legacyModelURL() throws -> URL {
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

    private static func moveItemReplacingDestination(from source: URL, to destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        do {
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            try FileManager.default.copyItem(at: source, to: destination)
            try? FileManager.default.removeItem(at: source)
        }
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
