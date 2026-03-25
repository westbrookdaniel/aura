import CoreAudio
import Testing
@testable import Aura

struct AudioDeviceManagerTests {
    @Test
    func resolvesPreferredBuiltInMicrophoneWhenNoExplicitSelectionExists() {
        let devices = [
            MicrophoneDevice(id: AudioDeviceID(101), name: "USB Audio Device", isDefault: true),
            MicrophoneDevice(id: AudioDeviceID(202), name: "MacBook Pro Microphone", isDefault: false)
        ]

        let resolvedID = AudioDeviceManager.resolvedInputDeviceID(
            selectedDeviceID: nil,
            usesSystemDefault: false,
            from: devices
        )

        #expect(resolvedID == AudioDeviceID(202))
    }

    @Test
    func keepsSystemDefaultWhenUserExplicitlyChoosesIt() {
        let devices = [
            MicrophoneDevice(id: AudioDeviceID(101), name: "USB Audio Device", isDefault: true),
            MicrophoneDevice(id: AudioDeviceID(202), name: "MacBook Pro Microphone", isDefault: false)
        ]

        let resolvedID = AudioDeviceManager.resolvedInputDeviceID(
            selectedDeviceID: nil,
            usesSystemDefault: true,
            from: devices
        )

        #expect(resolvedID == nil)
    }

    @Test
    func keepsSavedSelectionWhenThatDeviceIsStillAvailable() {
        let devices = [
            MicrophoneDevice(id: AudioDeviceID(101), name: "USB Audio Device", isDefault: true),
            MicrophoneDevice(id: AudioDeviceID(202), name: "MacBook Pro Microphone", isDefault: false)
        ]

        let resolvedID = AudioDeviceManager.resolvedInputDeviceID(
            selectedDeviceID: 101,
            usesSystemDefault: false,
            from: devices
        )

        #expect(resolvedID == AudioDeviceID(101))
    }
}
