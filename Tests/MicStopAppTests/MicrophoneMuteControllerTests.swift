import CoreAudio
@testable import MicStopApp
import Testing

struct MicrophoneMuteControllerTests {
    @Test
    func prefersProcessMuteWhenAvailable() throws {
        let audio = MockAudioHardware()
        audio.supportsProcessInputMuteStorage = true
        audio.deviceMuteSupported = true

        let controller = MicrophoneMuteController(audioHardware: audio)

        let strategy = controller.strategy(for: audio.defaultInputDeviceIDStorage)

        #expect(strategy == .deviceMute)
    }

    @Test
    func fallsBackToProcessMuteOnlyWhenDeviceControlsAreUnavailable() throws {
        let audio = MockAudioHardware()
        audio.supportsProcessInputMuteStorage = true
        audio.deviceMuteSupported = false
        audio.volumeSupported = false

        let controller = MicrophoneMuteController(audioHardware: audio)

        let strategy = controller.strategy(for: audio.defaultInputDeviceIDStorage)

        #expect(strategy == .processMute)
    }

    @Test
    func restoresPreviousVolumePerDevice() throws {
        let audio = MockAudioHardware()
        audio.supportsProcessInputMuteStorage = false
        audio.deviceMuteSupported = false
        audio.volumeSupported = true
        audio.defaultInputDeviceIDStorage = 101
        audio.volumeByDevice[101] = 0.66

        let controller = MicrophoneMuteController(audioHardware: audio)
        try controller.setDesiredMute(.muted)
        #expect(audio.volumeByDevice[101] == 0)

        audio.defaultInputDeviceIDStorage = 202
        audio.volumeByDevice[202] = 0.42
        try controller.handleDefaultInputDeviceChanged()
        #expect(audio.volumeByDevice[202] == 0)

        audio.defaultInputDeviceIDStorage = 101
        try controller.setDesiredMute(.unmuted)
        #expect(audio.volumeByDevice[101] == 0.66)

        audio.defaultInputDeviceIDStorage = 202
        try controller.handleDefaultInputDeviceChanged()
        #expect(audio.volumeByDevice[202] == 0.42)
    }

    @Test
    func explicitMuteAndUnmuteUseSameVolumeRestorationPath() throws {
        let audio = MockAudioHardware()
        audio.supportsProcessInputMuteStorage = false
        audio.deviceMuteSupported = false
        audio.volumeSupported = true
        audio.defaultInputDeviceIDStorage = 404
        audio.volumeByDevice[404] = 0.73

        let controller = MicrophoneMuteController(audioHardware: audio)

        try controller.mute()
        #expect(audio.volumeByDevice[404] == 0)

        try controller.unmute()
        #expect(audio.volumeByDevice[404] == 0.73)
    }

    @Test
    func desiredMuteStateSurvivesDeviceSwitch() throws {
        let audio = MockAudioHardware()
        audio.supportsProcessInputMuteStorage = false
        audio.deviceMuteSupported = true
        audio.defaultInputDeviceIDStorage = 1

        let controller = MicrophoneMuteController(audioHardware: audio)
        try controller.setDesiredMute(.muted)
        #expect(audio.deviceMuteByDevice[1] == true)

        audio.defaultInputDeviceIDStorage = 2
        try controller.handleDefaultInputDeviceChanged()

        #expect(controller.stateSnapshot.desiredMuteState == .muted)
        #expect(audio.deviceMuteByDevice[2] == true)
    }
}

final class MockAudioHardware: AudioHardwareControlling {
    var supportsProcessInputMuteStorage = false
    var defaultInputDeviceIDStorage: AudioDeviceID = 1
    var processInputMute = false
    var deviceMuteSupported = false
    var volumeSupported = false
    var volumeByDevice: [AudioDeviceID: Float32] = [:]
    var deviceMuteByDevice: [AudioDeviceID: Bool] = [:]

    var supportsProcessInputMute: Bool {
        supportsProcessInputMuteStorage
    }

    func defaultInputDeviceID() throws -> AudioDeviceID {
        defaultInputDeviceIDStorage
    }

    func deviceName(_ deviceID: AudioDeviceID) -> String {
        "Device \(deviceID)"
    }

    func getProcessInputMute() throws -> Bool {
        processInputMute
    }

    func setProcessInputMute(_ muted: Bool) throws {
        processInputMute = muted
    }

    func deviceSupportsMute(_ deviceID: AudioDeviceID) -> Bool {
        deviceMuteSupported
    }

    func getDeviceMute(_ deviceID: AudioDeviceID) throws -> Bool {
        deviceMuteByDevice[deviceID] ?? false
    }

    func setDeviceMute(_ deviceID: AudioDeviceID, muted: Bool) throws {
        deviceMuteByDevice[deviceID] = muted
    }

    func deviceSupportsVolume(_ deviceID: AudioDeviceID) -> Bool {
        volumeSupported
    }

    func getInputVolume(_ deviceID: AudioDeviceID) throws -> Float32 {
        volumeByDevice[deviceID] ?? 0
    }

    func setInputVolume(_ deviceID: AudioDeviceID, volume: Float32) throws {
        volumeByDevice[deviceID] = volume
    }
}
