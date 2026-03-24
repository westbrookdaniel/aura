@preconcurrency import AVFoundation
import Foundation

struct AudioPreprocessingConfiguration: Equatable, Codable {
    var targetPeakNormal: Float = 0.55
    var targetPeakQuiet: Float = 0.82
    var silenceThreshold: Float = 0.008
    var whisperRMSUpperBound: Float = 0.045
    var quietRMSUpperBound: Float = 0.09
}

enum AudioSpeechProfile: String, Equatable, Codable {
    case normal
    case quiet
    case whisperLike
    case mostlySilent
}

struct AudioAnalysisResult: Equatable, Codable {
    var peak: Float
    var rms: Float
    var silenceRatio: Float
    var dynamicRange: Float
    var profile: AudioSpeechProfile
    var leadingSilenceRatio: Float
    var clippedStartLikely: Bool
}

struct PreprocessedAudioResult: Equatable {
    var fileURL: URL
    var analysis: AudioAnalysisResult
}

enum AudioPreprocessor {
    static func preprocess(audioURL: URL, configuration: AudioPreprocessingConfiguration) throws -> PreprocessedAudioResult {
        let file = try AVAudioFile(forReading: audioURL)
        let inputFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else {
            throw AudioPreprocessorError.couldNotAllocateBuffer
        }
        try file.read(into: buffer)

        let samples = try extractMonoSamples(from: buffer)
        let analysis = analyze(samples: samples, configuration: configuration)

        if analysis.profile == .mostlySilent {
            return PreprocessedAudioResult(fileURL: audioURL, analysis: analysis)
        }

        let normalized = normalize(samples: samples, analysis: analysis, configuration: configuration)

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("listener-preprocessed-\(UUID().uuidString).wav")
        let pcmData = pcm16Data(from: normalized)
        let wavData = WAVEncoder.wrapPCM16Mono(pcmData: pcmData, sampleRate: 16_000)
        try wavData.write(to: outputURL, options: .atomic)
        return PreprocessedAudioResult(fileURL: outputURL, analysis: analysis)
    }

    private static func extractMonoSamples(from buffer: AVAudioPCMBuffer) throws -> [Float] {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return [] }

        if let channelData = buffer.floatChannelData?[0] {
            return Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        }

        if let int16Data = buffer.int16ChannelData?[0] {
            return (0..<frameCount).map { Float(int16Data[$0]) / Float(Int16.max) }
        }

        throw AudioPreprocessorError.unsupportedSourceFormat
    }

    private static func analyze(samples: [Float], configuration: AudioPreprocessingConfiguration) -> AudioAnalysisResult {
        guard samples.isEmpty == false else {
            return AudioAnalysisResult(
                peak: 0,
                rms: 0,
                silenceRatio: 1,
                dynamicRange: 0,
                profile: .mostlySilent,
                leadingSilenceRatio: 1,
                clippedStartLikely: false
            )
        }

        let magnitudes = samples.map { abs($0) }
        let peak = magnitudes.max() ?? 0
        let rms = sqrt(magnitudes.reduce(0) { $0 + ($1 * $1) } / Float(magnitudes.count))
        let silenceCount = magnitudes.filter { $0 < configuration.silenceThreshold }.count
        let silenceRatio = Float(silenceCount) / Float(magnitudes.count)
        let leadingWindowSize = min(magnitudes.count, 2_400)
        let leadingWindow = Array(magnitudes.prefix(leadingWindowSize))
        let leadingSilenceCount = leadingWindow.filter { $0 < configuration.silenceThreshold }.count
        let leadingSilenceRatio = leadingWindow.isEmpty ? 1 : Float(leadingSilenceCount) / Float(leadingWindow.count)
        let sorted = magnitudes.sorted()
        let p95 = sorted[min(sorted.count - 1, Int(Float(sorted.count - 1) * 0.95))]
        let p20 = sorted[min(sorted.count - 1, Int(Float(sorted.count - 1) * 0.20))]
        let dynamicRange = max(0, p95 - p20)
        let firstSpeechIndex = magnitudes.firstIndex { $0 >= configuration.silenceThreshold * 1.1 } ?? 0
        let clippedStartLikely = leadingSilenceRatio < 0.08 && firstSpeechIndex < min(magnitudes.count, 540)

        let profile: AudioSpeechProfile
        if peak < configuration.silenceThreshold * 2 || rms < 0.006 {
            profile = .mostlySilent
        } else if rms < configuration.whisperRMSUpperBound || (silenceRatio > 0.55 && dynamicRange < 0.12) {
            profile = .whisperLike
        } else if rms < configuration.quietRMSUpperBound {
            profile = .quiet
        } else {
            profile = .normal
        }

        return AudioAnalysisResult(
            peak: peak,
            rms: rms,
            silenceRatio: silenceRatio,
            dynamicRange: dynamicRange,
            profile: profile,
            leadingSilenceRatio: leadingSilenceRatio,
            clippedStartLikely: clippedStartLikely
        )
    }

    private static func normalize(samples: [Float], analysis: AudioAnalysisResult, configuration: AudioPreprocessingConfiguration) -> [Float] {
        guard samples.isEmpty == false else { return samples }
        guard analysis.peak > 0 else { return samples }

        let targetPeak: Float
        switch analysis.profile {
        case .whisperLike, .quiet:
            targetPeak = configuration.targetPeakQuiet
        case .mostlySilent:
            targetPeak = configuration.targetPeakNormal
        case .normal:
            targetPeak = configuration.targetPeakNormal
        }

        let gain = min(10.0, targetPeak / analysis.peak)
        return samples.map { sample in
            let boosted = sample * gain
            let compressed = tanh(boosted * 1.35) / tanh(1.35)
            return max(-1, min(1, compressed))
        }
    }

    private static func pcm16Data(from samples: [Float]) -> Data {
        var pcm = Data(capacity: samples.count * MemoryLayout<Int16>.size)
        for sample in samples {
            var intValue = Int16(max(-1, min(1, sample)) * Float(Int16.max))
            pcm.append(Data(bytes: &intValue, count: MemoryLayout<Int16>.size))
        }
        return pcm
    }
}

enum AudioPreprocessorError: LocalizedError {
    case couldNotAllocateBuffer
    case unsupportedSourceFormat

    var errorDescription: String? {
        switch self {
        case .couldNotAllocateBuffer:
            return "The audio preprocessor could not allocate a working buffer."
        case .unsupportedSourceFormat:
            return "The recorded audio format is not supported by the preprocessor."
        }
    }
}
