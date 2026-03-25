@preconcurrency import AVFoundation
import Foundation

struct AudioPreprocessingConfiguration: Equatable, Codable {
    var targetPeakNormal: Float = 0.55
    var targetPeakQuiet: Float = 0.72
    var silenceThreshold: Float = 0.008
    var whisperRMSUpperBound: Float = 0.045
    var quietRMSUpperBound: Float = 0.09
    var normalCompressionDrive: Float = 1.25
    var quietCompressionDrive: Float = 1.55
    var quietActivationThresholdMultiplier: Float = 1.6
    var quietMinimumFloor: Float = 0.018
    var whisperMinimumFloor: Float = 0.03
    var quietUpwardCompressionExponent: Float = 0.94
    var whisperUpwardCompressionExponent: Float = 0.88
    var quietUpwardCompressionBlend: Float = 0.22
    var whisperUpwardCompressionBlend: Float = 0.34
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

        let normalized = analysis.profile == .mostlySilent
            ? samples
            : normalize(samples: samples, analysis: analysis, configuration: configuration)
        let targetSampleRate = 16_000.0
        let outputSamples = resample(samples: normalized, from: inputFormat.sampleRate, to: targetSampleRate)

        if analysis.profile == .mostlySilent, abs(inputFormat.sampleRate - targetSampleRate) < 0.5 {
            return PreprocessedAudioResult(fileURL: audioURL, analysis: analysis)
        }

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("aura-preprocessed-\(UUID().uuidString).wav")
        let wavData = WAVEncoder.wrapPCM16Mono(samples: outputSamples, sampleRate: Int(targetSampleRate))
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
        let compressionDrive: Float
        let minimumFloor: Float
        let upwardCompressionExponent: Float
        let upwardCompressionBlend: Float
        switch analysis.profile {
        case .whisperLike:
            targetPeak = configuration.targetPeakQuiet
            compressionDrive = configuration.quietCompressionDrive
            minimumFloor = configuration.whisperMinimumFloor
            upwardCompressionExponent = configuration.whisperUpwardCompressionExponent
            upwardCompressionBlend = configuration.whisperUpwardCompressionBlend
        case .quiet:
            targetPeak = configuration.targetPeakQuiet
            compressionDrive = configuration.quietCompressionDrive
            minimumFloor = configuration.quietMinimumFloor
            upwardCompressionExponent = configuration.quietUpwardCompressionExponent
            upwardCompressionBlend = configuration.quietUpwardCompressionBlend
        case .mostlySilent:
            targetPeak = configuration.targetPeakNormal
            compressionDrive = configuration.normalCompressionDrive
            minimumFloor = 0
            upwardCompressionExponent = 1
            upwardCompressionBlend = 0
        case .normal:
            targetPeak = configuration.targetPeakNormal
            compressionDrive = configuration.normalCompressionDrive
            minimumFloor = 0
            upwardCompressionExponent = 1
            upwardCompressionBlend = 0
        }

        let gain = min(10.0, targetPeak / analysis.peak)
        let activationThreshold = configuration.silenceThreshold * configuration.quietActivationThresholdMultiplier

        return samples.map { sample in
            let boosted = sample * gain
            let upwardCompressed = applyUpwardCompression(
                to: boosted,
                activationThreshold: activationThreshold,
                minimumFloor: minimumFloor,
                exponent: upwardCompressionExponent,
                blend: upwardCompressionBlend
            )
            let compressed = tanh(upwardCompressed * compressionDrive) / tanh(compressionDrive)
            return max(-1, min(1, compressed))
        }
    }

    private static func applyUpwardCompression(
        to sample: Float,
        activationThreshold: Float,
        minimumFloor: Float,
        exponent: Float,
        blend: Float
    ) -> Float {
        let magnitude = abs(sample)
        guard magnitude > activationThreshold else { return sample }

        let sign: Float = sample < 0 ? -1 : 1
        var enhancedMagnitude = magnitude

        if exponent < 1 {
            enhancedMagnitude = pow(magnitude, exponent)
        }

        if minimumFloor > 0 {
            enhancedMagnitude = max(enhancedMagnitude, minimumFloor)
        }

        if blend > 0 {
            enhancedMagnitude = (magnitude * (1 - blend)) + (enhancedMagnitude * blend)
        }

        return sign * enhancedMagnitude
    }

    private static func resample(samples: [Float], from sourceSampleRate: Double, to targetSampleRate: Double) -> [Float] {
        guard samples.isEmpty == false else { return [] }
        guard sourceSampleRate > 0, targetSampleRate > 0 else { return samples }
        guard abs(sourceSampleRate - targetSampleRate) >= 0.5 else { return samples }

        let outputCount = max(1, Int((Double(samples.count) * targetSampleRate / sourceSampleRate).rounded()))
        let lastSourceIndex = samples.count - 1
        var output = Array(repeating: Float.zero, count: outputCount)

        for outputIndex in 0..<outputCount {
            let sourcePosition = (Double(outputIndex) * sourceSampleRate) / targetSampleRate
            let lowerIndex = min(lastSourceIndex, Int(sourcePosition))
            let upperIndex = min(lastSourceIndex, lowerIndex + 1)
            let fraction = Float(sourcePosition - Double(lowerIndex))
            let lowerSample = samples[lowerIndex]
            let upperSample = samples[upperIndex]
            output[outputIndex] = lowerSample + ((upperSample - lowerSample) * fraction)
        }

        return output
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
