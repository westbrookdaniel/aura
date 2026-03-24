@preconcurrency import AVFoundation
import AudioToolbox
import Combine
import Foundation

final class AudioRecorder: ObservableObject, @unchecked Sendable {
    @Published private(set) var normalizedLevels: [Double] = Array(repeating: 0, count: 40)

    private let engine = AVAudioEngine()
    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )
    private let stateLock = NSLock()
    private var pcmBuffer = Data()
    private var recordingURL: URL?
    private var isRecording = false

    func startRecording(preferredDeviceID: AudioDeviceID?) throws -> URL {
        guard !isRecording else { throw AudioRecorderError.alreadyRecording }
        guard let outputFormat else { throw AudioRecorderError.unsupportedFormat }

        try configureInputDevice(preferredDeviceID)

        stateLock.lock()
        pcmBuffer = Data()
        stateLock.unlock()
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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.normalizedLevels = Array(repeating: 0, count: self.normalizedLevels.count)
        }

        stateLock.lock()
        let wavData = WAVEncoder.wrapPCM16Mono(
            pcmData: pcmBuffer,
            sampleRate: 16_000
        )
        stateLock.unlock()
        try wavData.write(to: recordingURL, options: .atomic)
        return recordingURL
    }

    private func configureInputDevice(_ deviceID: AudioDeviceID?) throws {
        guard let audioUnit = engine.inputNode.audioUnit else {
            throw AudioRecorderError.inputDeviceUnavailable
        }
        guard var deviceID else { return }

        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        guard status == noErr else {
            throw AudioRecorderError.couldNotSelectInputDevice
        }
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
        stateLock.lock()
        pcmBuffer.append(data)
        stateLock.unlock()
    }

    private func publishLevels(from buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.int16ChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        let bucketCount = 40
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

            var peak: Int16 = 0
            for index in start..<end {
                peak = max(peak, abs(channel[index]))
            }
            nextLevels.append(min(1, Double(peak) / Double(Int16.max)))
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
    case inputDeviceUnavailable
    case couldNotSelectInputDevice

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
        case .inputDeviceUnavailable:
            return "The recorder could not access the input audio unit."
        case .couldNotSelectInputDevice:
            return "The selected microphone could not be activated."
        }
    }
}
