import CoreAudio
import Foundation

struct MicrophoneDevice: Identifiable, Equatable, Hashable {
    let id: AudioDeviceID
    let name: String
    let isDefault: Bool

    var stableID: UInt32 { id }
    var displayName: String { name }
}

enum AudioDeviceManager {
    static func availableInputDevices() -> [MicrophoneDevice] {
        let defaultInputID = defaultInputDeviceID()
        let deviceIDs = systemDeviceIDs()

        return deviceIDs.compactMap { deviceID in
            guard inputChannelCount(for: deviceID) > 0 else { return nil }
            guard let name = deviceName(for: deviceID), name.isEmpty == false else { return nil }
            return MicrophoneDevice(id: deviceID, name: name, isDefault: deviceID == defaultInputID)
        }
        .sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func defaultInputDeviceID() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        guard status == noErr, deviceID != 0 else { return nil }
        return deviceID
    }

    static func inputDeviceName(for deviceID: AudioDeviceID) -> String? {
        deviceName(for: deviceID)
    }

    static func preferredBuiltInInputDeviceID(from devices: [MicrophoneDevice]? = nil) -> AudioDeviceID? {
        let availableDevices = devices ?? availableInputDevices()
        let defaultInputID = defaultInputDeviceID()

        if let directMatch = availableDevices.first(where: isPreferredBuiltInMicrophone) {
            return directMatch.id
        }

        if let defaultInputID,
           availableDevices.contains(where: { $0.id == defaultInputID }) {
            return defaultInputID
        }

        return availableDevices.first?.id
    }

    private static func systemDeviceIDs() -> [AudioDeviceID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr, dataSize > 0 else { return [] }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(0), count: count)

        let readStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard readStatus == noErr else { return [] }
        return deviceIDs
    }

    private static func inputChannelCount(for deviceID: AudioDeviceID) -> Int {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return 0 }

        let bufferListPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferListPointer.deallocate() }

        let readStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            bufferListPointer
        )
        guard readStatus == noErr else { return 0 }

        let bufferList = bufferListPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        let audioBufferList = UnsafeMutableAudioBufferListPointer(bufferList)
        return audioBufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func deviceName(for deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutableBytes(of: &cfName) { rawBuffer in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                rawBuffer.baseAddress!
            )
        }

        guard status == noErr, let cfName else { return nil }
        return cfName as String
    }

    private static func isPreferredBuiltInMicrophone(_ device: MicrophoneDevice) -> Bool {
        let lowered = device.name.lowercased()
        let builtInSignals = [
            "macbook",
            "built-in",
            "built in",
            "internal microphone",
            "microphone"
        ]

        guard builtInSignals.contains(where: lowered.contains) else {
            return false
        }

        let externalSignals = [
            "airpods",
            "usb",
            "display",
            "headset",
            "headphones",
            "bluetooth",
            "webcam"
        ]

        return externalSignals.contains(where: lowered.contains) == false
    }
}
