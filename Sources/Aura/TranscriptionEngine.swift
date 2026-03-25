@preconcurrency import AVFoundation
import Foundation
import whisper

protocol TranscriptionEngine: Sendable {
    func prepare(configuration: TranscriptionConfiguration) async throws
    func transcribe(audioURL: URL, configuration: TranscriptionConfiguration) async throws -> TranscriptionResult
}

actor WhisperCPPTranscriptionEngine: TranscriptionEngine {
    private var context: OpaquePointer?
    private var loadedModelPath: String?

    func prepare(configuration: TranscriptionConfiguration) async throws {
        let modelPath = NSString(string: configuration.modelPath).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperEngineError.modelNotFound(modelPath)
        }

        try loadContextIfNeeded(modelPath: modelPath)
    }

    func transcribe(audioURL: URL, configuration: TranscriptionConfiguration) async throws -> TranscriptionResult {
        let modelPath = NSString(string: configuration.modelPath).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperEngineError.modelNotFound(modelPath)
        }

        try loadContextIfNeeded(modelPath: modelPath)
        guard let context else {
            throw WhisperEngineError.modelLoadFailed("whisper.cpp did not return a model context.")
        }

        let samples = try loadSamples(from: audioURL)
        guard samples.isEmpty == false else {
            return TranscriptionResult(text: "", analysis: nil)
        }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_context = true
        params.no_timestamps = true
        params.single_segment = false
        params.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 1)))

        let language = strdup("en")
        defer { free(language) }
        params.language = UnsafePointer(language)

        let status = samples.withUnsafeBufferPointer { buffer in
            whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
        }

        guard status == 0 else {
            throw WhisperEngineError.transcriptionFailed("whisper.cpp returned status \(status).")
        }

        let segmentCount = Int(whisper_full_n_segments(context))
        var segments: [String] = []
        segments.reserveCapacity(segmentCount)

        for segmentIndex in 0..<segmentCount {
            guard let textPointer = whisper_full_get_segment_text(context, Int32(segmentIndex)) else { continue }
            let text = String(cString: textPointer).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty == false {
                segments.append(text)
            }
        }

        let transcript = segments.joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard transcript.isEmpty == false else {
            return TranscriptionResult(text: "", analysis: nil)
        }

        return TranscriptionResult(text: transcript, analysis: nil)
    }

    private func loadContextIfNeeded(modelPath: String) throws {
        if loadedModelPath == modelPath, context != nil {
            return
        }

        if let context {
            whisper_free(context)
            self.context = nil
            loadedModelPath = nil
        }

        let contextParams = whisper_context_default_params()
        guard let newContext = modelPath.withCString({ whisper_init_from_file_with_params($0, contextParams) }) else {
            throw WhisperEngineError.modelLoadFailed("whisper.cpp could not load the model at \(modelPath).")
        }

        context = newContext
        loadedModelPath = modelPath
    }

    private func loadSamples(from audioURL: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: audioURL)
        let inputFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else {
            throw WhisperEngineError.transcriptionFailed("The recorder could not allocate the transcription buffer.")
        }

        try file.read(into: buffer)
        return try extractMonoSamples(from: buffer)
    }

    private func extractMonoSamples(from buffer: AVAudioPCMBuffer) throws -> [Float] {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return [] }

        if let channelData = buffer.floatChannelData?[0] {
            return Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        }

        if let int16Data = buffer.int16ChannelData?[0] {
            return (0..<frameCount).map { Float(int16Data[$0]) / Float(Int16.max) }
        }

        throw WhisperEngineError.transcriptionFailed("The prepared audio file used an unsupported format.")
    }
}

enum WhisperEngineError: LocalizedError {
    case modelNotFound(String)
    case modelLoadFailed(String)
    case transcriptionFailed(String)
    case transcriptionOutputMissing(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Whisper model file was not found at \(path)."
        case .modelLoadFailed(let message):
            return "whisper.cpp could not load the model: \(message)"
        case .transcriptionFailed(let message):
            return "whisper.cpp failed: \(message)"
        case .transcriptionOutputMissing(let message):
            return "whisper.cpp finished but did not produce readable output: \(message)"
        }
    }
}
