@preconcurrency import AVFoundation
import AudioToolbox
import Combine
import Foundation

final class AudioRecorder: ObservableObject, @unchecked Sendable {
    @Published private(set) var normalizedLevels: [Double] = Array(repeating: 0, count: 40)

    private let meteringEngine = AVAudioEngine()
    private let stateLock = NSLock()
    private var recordingURL: URL?
    private var recordingProcess: Process?
    private var fallbackMeterTask: Task<Void, Never>?
    private var isRecording = false

    func startRecording(soxBinaryPath: String, preferredDeviceID: AudioDeviceID?, preferredDeviceName: String?) throws -> URL {
        guard !isRecording else { throw AudioRecorderError.alreadyRecording }
        let binaryPath = NSString(string: soxBinaryPath).expandingTildeInPath
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw AudioRecorderError.binaryNotFound(binaryPath)
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("listener-\(UUID().uuidString).wav")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)

        var arguments = ["-q"]
        if let preferredDeviceName, !preferredDeviceName.isEmpty {
            arguments.append(contentsOf: ["-t", "coreaudio", preferredDeviceName])
        } else {
            arguments.append("-d")
        }
        arguments.append(contentsOf: [
            "-b", "16",
            "-c", "1",
            "-r", "16000",
            "-e", "signed-integer",
            "-t", "wav",
            tempURL.path
        ])
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            throw AudioRecorderError.couldNotStartProcess(error.localizedDescription)
        }

        stateLock.lock()
        recordingProcess = process
        recordingURL = tempURL
        stateLock.unlock()
        isRecording = true
        startMetering(preferredDeviceID: preferredDeviceID)
        return tempURL
    }

    func stop() throws -> URL {
        guard isRecording, let recordingURL else { throw AudioRecorderError.notRecording }

        stateLock.lock()
        let recordingProcess = self.recordingProcess
        self.recordingProcess = nil
        stateLock.unlock()

        recordingProcess?.interrupt()
        recordingProcess?.waitUntilExit()

        isRecording = false
        stopMetering()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.normalizedLevels = Array(repeating: 0, count: self.normalizedLevels.count)
        }

        if let recordingProcess, recordingProcess.terminationStatus != 0, recordingProcess.terminationReason != .exit {
            throw AudioRecorderError.couldNotStopProcess
        }

        return recordingURL
    }

    private func startMetering(preferredDeviceID: AudioDeviceID?) {
        fallbackMeterTask?.cancel()
        fallbackMeterTask = nil

        do {
            try configureMeteringInputDevice(preferredDeviceID)

            let inputNode = meteringEngine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, _ in
                self?.publishLevels(from: buffer)
            }

            meteringEngine.prepare()
            try meteringEngine.start()
        } catch {
            startFallbackMetering()
        }
    }

    private func stopMetering() {
        fallbackMeterTask?.cancel()
        fallbackMeterTask = nil
        meteringEngine.inputNode.removeTap(onBus: 0)
        meteringEngine.stop()
        meteringEngine.reset()
    }

    private func configureMeteringInputDevice(_ deviceID: AudioDeviceID?) throws {
        guard let audioUnit = meteringEngine.inputNode.audioUnit else {
            throw AudioRecorderError.couldNotStartProcess("Could not access the metering input.")
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

    private func publishLevels(from buffer: AVAudioPCMBuffer) {
        let samples = extractSamples(from: buffer)
        guard samples.isEmpty == false else { return }

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
            levels.append(min(1, Double(peak)))
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.normalizedLevels = levels
        }
    }

    private func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return [] }

        if let channelData = buffer.floatChannelData?[0] {
            return Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        }

        if let int16Data = buffer.int16ChannelData?[0] {
            return (0..<frameCount).map { Float(int16Data[$0]) / Float(Int16.max) }
        }

        return []
    }

    private func startFallbackMetering() {
        fallbackMeterTask?.cancel()
        fallbackMeterTask = Task { @MainActor [weak self] in
            var phase = 0.0
            while Task.isCancelled == false {
                let amplitude = 0.16 + ((sin(phase) + 1) * 0.12)
                self?.normalizedLevels = Array(repeating: amplitude, count: self?.normalizedLevels.count ?? 40)
                phase += 0.45
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case alreadyRecording
    case notRecording
    case binaryNotFound(String)
    case couldNotStartProcess(String)
    case couldNotStopProcess

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Audio capture is already in progress."
        case .notRecording:
            return "Audio capture was not running."
        case .binaryNotFound(let path):
            return "SoX was not found at \(path). Install it in Settings, then try again."
        case .couldNotStartProcess(let message):
            return "The recorder could not start SoX: \(message)"
        case .couldNotStopProcess:
            return "The recorder could not stop SoX cleanly."
        }
    }
}
