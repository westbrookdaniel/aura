@preconcurrency import AVFoundation
import AudioToolbox
import Combine
import Foundation

final class AudioRecorder: ObservableObject, @unchecked Sendable {
    @Published private(set) var normalizedLevels: [Double] = Array(repeating: 0, count: 40)

    private let recordingEngine = AVAudioEngine()
    private let stateLock = NSLock()
    private let levelProcessingLock = NSLock()
    private var recordingURL: URL?
    private var recordedSamples: [Float] = []
    private var recordedSampleRate: Double = 16_000
    private var isRecording = false
    private var recentPeak: Double = 0.12

    func startRecording(preferredDeviceID: AudioDeviceID?) throws -> URL {
        stateLock.lock()
        let alreadyRecording = isRecording
        stateLock.unlock()
        guard alreadyRecording == false else { throw AudioRecorderError.alreadyRecording }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("aura-\(UUID().uuidString).wav")

        do {
            try configureInputDevice(preferredDeviceID)

            let inputNode = recordingEngine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)
            guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
                throw AudioRecorderError.couldNotStartProcess("The selected microphone did not provide a usable audio format.")
            }

            stateLock.lock()
            recordingURL = tempURL
            recordedSamples = []
            recordedSampleRate = inputFormat.sampleRate
            isRecording = true
            stateLock.unlock()

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, _ in
                self?.handleInputBuffer(buffer)
            }

            recordingEngine.prepare()
            try recordingEngine.start()
        } catch {
            resetStateAfterFailure()
            if let recorderError = error as? AudioRecorderError {
                throw recorderError
            }
            throw AudioRecorderError.couldNotStartProcess(error.localizedDescription)
        }

        return tempURL
    }

    func stop() throws -> URL {
        stateLock.lock()
        let currentRecordingURL = recordingURL
        let currentlyRecording = isRecording
        stateLock.unlock()
        guard currentlyRecording, let currentRecordingURL else { throw AudioRecorderError.notRecording }

        stopCapture()

        let finalSamples: [Float]
        let sampleRate: Double
        stateLock.lock()
        finalSamples = recordedSamples
        sampleRate = recordedSampleRate
        recordingURL = nil
        recordedSamples = []
        recordedSampleRate = 16_000
        stateLock.unlock()

        let wavData = WAVEncoder.wrapPCM16Mono(
            samples: finalSamples,
            sampleRate: max(1, Int(sampleRate.rounded()))
        )
        do {
            try wavData.write(to: currentRecordingURL, options: .atomic)
        } catch {
            throw AudioRecorderError.couldNotStopProcess(error.localizedDescription)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.normalizedLevels = Array(repeating: 0, count: self.normalizedLevels.count)
        }

        return currentRecordingURL
    }

    private func configureInputDevice(_ deviceID: AudioDeviceID?) throws {
        guard let audioUnit = recordingEngine.inputNode.audioUnit else {
            throw AudioRecorderError.couldNotStartProcess("Could not access the microphone input.")
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
            throw AudioRecorderError.couldNotStartProcess("Could not select the requested microphone.")
        }
    }

    private func handleInputBuffer(_ buffer: AVAudioPCMBuffer) {
        let samples = extractMonoSamples(from: buffer)
        guard samples.isEmpty == false else { return }

        stateLock.lock()
        if isRecording {
            recordedSamples.append(contentsOf: samples)
        }
        stateLock.unlock()

        publishLevels(samples)
    }

    private func stopCapture() {
        stateLock.lock()
        isRecording = false
        stateLock.unlock()
        recordingEngine.inputNode.removeTap(onBus: 0)
        recordingEngine.stop()
        recordingEngine.reset()
    }

    private func resetStateAfterFailure() {
        recordingEngine.inputNode.removeTap(onBus: 0)
        recordingEngine.stop()
        recordingEngine.reset()
        stateLock.lock()
        recordingURL = nil
        recordedSamples = []
        recordedSampleRate = 16_000
        isRecording = false
        stateLock.unlock()
    }

    private func publishLevels(_ samples: [Float]) {
        let bucketCount = normalizedLevels.count
        let bucketSize = max(1, samples.count / bucketCount)
        var levels: [Double] = []
        levels.reserveCapacity(bucketCount)

        for bucketIndex in 0..<bucketCount {
            let start = bucketIndex * bucketSize
            let end = min(samples.count, start + bucketSize)
            guard start < end else {
                levels.append(0)
                continue
            }

            var peak: Float = 0
            for sample in samples[start..<end] {
                peak = max(peak, abs(sample))
            }
            levels.append(Double(peak))
        }

        let processedLevels = normalizeLevels(levels)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.normalizedLevels = processedLevels
        }
    }

    private func normalizeLevels(_ levels: [Double]) -> [Double] {
        levelProcessingLock.lock()
        defer { levelProcessingLock.unlock() }

        let peak = max(levels.max() ?? 0, 0.02)
        recentPeak = max(peak, recentPeak * 0.92)
        let normalizationBase = max(recentPeak, 0.06)
        let gain = min(10.0, 0.9 / normalizationBase)

        return levels.map { level in
            let boosted = min(1, level * gain)
            let curved = pow(boosted, 0.62)
            return min(1, curved)
        }
    }

    private func extractMonoSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return [] }

        if let channelData = buffer.floatChannelData {
            var mono = Array(repeating: Float.zero, count: frameCount)
            for channelIndex in 0..<channelCount {
                let channel = UnsafeBufferPointer(start: channelData[channelIndex], count: frameCount)
                for frameIndex in 0..<frameCount {
                    mono[frameIndex] += channel[frameIndex]
                }
            }

            if channelCount > 1 {
                let scale = 1 / Float(channelCount)
                for index in mono.indices {
                    mono[index] *= scale
                }
            }

            return mono
        }

        if let channelData = buffer.int16ChannelData {
            var mono = Array(repeating: Float.zero, count: frameCount)
            for channelIndex in 0..<channelCount {
                let channel = UnsafeBufferPointer(start: channelData[channelIndex], count: frameCount)
                for frameIndex in 0..<frameCount {
                    mono[frameIndex] += Float(channel[frameIndex]) / Float(Int16.max)
                }
            }

            if channelCount > 1 {
                let scale = 1 / Float(channelCount)
                for index in mono.indices {
                    mono[index] *= scale
                }
            }

            return mono
        }

        return []
    }
}

enum AudioRecorderError: LocalizedError {
    case alreadyRecording
    case notRecording
    case couldNotStartProcess(String)
    case couldNotStopProcess(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Audio capture is already in progress."
        case .notRecording:
            return "Audio capture was not running."
        case .couldNotStartProcess(let message):
            return "The recorder could not start: \(message)"
        case .couldNotStopProcess(let message):
            return "The recorder could not finalize the audio capture: \(message)"
        }
    }
}
