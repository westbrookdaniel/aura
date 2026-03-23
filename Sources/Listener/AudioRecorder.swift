@preconcurrency import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioRecorder: ObservableObject {
    @Published private(set) var normalizedLevels: [Double] = Array(repeating: 0, count: 24)

    private let engine = AVAudioEngine()
    private let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)
    private var pcmBuffer = Data()
    private var recordingURL: URL?
    private var isRecording = false

    func startRecording() throws -> URL {
        guard !isRecording else { throw AudioRecorderError.alreadyRecording }
        guard let outputFormat else { throw AudioRecorderError.unsupportedFormat }

        pcmBuffer = Data()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("whisperbar-\(UUID().uuidString).wav")
        recordingURL = tempURL

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        guard let converter else { throw AudioRecorderError.converterUnavailable }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.handle(buffer: buffer, converter: converter, outputFormat: outputFormat)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
        return tempURL
    }

    func stop() throws -> URL {
        guard isRecording, let recordingURL else { throw AudioRecorderError.notRecording }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        normalizedLevels = Array(repeating: 0, count: normalizedLevels.count)

        let wavData = WAVEncoder.wrapPCM16Mono(
            pcmData: pcmBuffer,
            sampleRate: 16_000
        )
        try wavData.write(to: recordingURL, options: .atomic)
        return recordingURL
    }

    private func handle(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, outputFormat: AVAudioFormat) {
        guard let converted = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: 1024
        ) else { return }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: converted, error: &error, withInputFrom: inputBlock)
        guard error == nil else { return }
        appendPCM(buffer: converted)
        publishLevels(from: converted)
    }

    private func appendPCM(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.int16ChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        let data = Data(bytes: channelData, count: frameCount * MemoryLayout<Int16>.size)
        pcmBuffer.append(data)
    }

    private func publishLevels(from buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        let bucketCount = normalizedLevels.count
        let bucketSize = max(1, frameCount / bucketCount)
        var nextLevels: [Double] = []
        nextLevels.reserveCapacity(bucketCount)

        for bucketIndex in 0..<bucketCount {
            let start = bucketIndex * bucketSize
            let end = min(frameCount, start + bucketSize)
            guard start < end else {
                nextLevels.append(0)
                continue
            }

            var peak: Float = 0
            for index in start..<end {
                peak = max(peak, abs(channel[index]))
            }
            nextLevels.append(min(1, Double(peak) * 4))
        }

        DispatchQueue.main.async { [weak self] in
            self?.normalizedLevels = nextLevels
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case alreadyRecording
    case notRecording
    case unsupportedFormat
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Audio capture is already in progress."
        case .notRecording:
            return "Audio capture was not running."
        case .unsupportedFormat:
            return "The recorder could not create a Whisper-compatible format."
        case .converterUnavailable:
            return "The recorder could not create an audio converter."
        }
    }
}
