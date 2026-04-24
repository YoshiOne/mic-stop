import CoreAudio
import Foundation

protocol AudioHardwareControlling: AnyObject {
    var supportsProcessInputMute: Bool { get }

    func defaultInputDeviceID() throws -> AudioDeviceID
    func deviceName(_ deviceID: AudioDeviceID) -> String

    func getProcessInputMute() throws -> Bool
    func setProcessInputMute(_ muted: Bool) throws

    func deviceSupportsMute(_ deviceID: AudioDeviceID) -> Bool
    func getDeviceMute(_ deviceID: AudioDeviceID) throws -> Bool
    func setDeviceMute(_ deviceID: AudioDeviceID, muted: Bool) throws

    func deviceSupportsVolume(_ deviceID: AudioDeviceID) -> Bool
    func getInputVolume(_ deviceID: AudioDeviceID) throws -> Float32
    func setInputVolume(_ deviceID: AudioDeviceID, volume: Float32) throws
}

final class SystemAudioHardwareController: AudioHardwareControlling {
    var supportsProcessInputMute: Bool {
        hasProperty(objectID: AudioObjectID(kAudioObjectSystemObject), address: processInputMuteAddress)
    }

    func defaultInputDeviceID() throws -> AudioDeviceID {
        let deviceID = try read(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: defaultInputDeviceAddress,
            as: AudioDeviceID.self
        )

        guard deviceID != kAudioObjectUnknown else {
            throw AudioHardwareError.noInputDevice
        }

        return deviceID
    }

    func deviceName(_ deviceID: AudioDeviceID) -> String {
        (try? read(objectID: deviceID, address: nameAddress, as: CFString.self) as String) ?? "Unknown Microphone"
    }

    func getProcessInputMute() throws -> Bool {
        let value: UInt32 = try read(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: processInputMuteAddress,
            as: UInt32.self
        )

        return value != 0
    }

    func setProcessInputMute(_ muted: Bool) throws {
        try write(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: processInputMuteAddress,
            value: UInt32(muted ? 1 : 0)
        )
    }

    func deviceSupportsMute(_ deviceID: AudioDeviceID) -> Bool {
        muteElement(for: deviceID) != nil
    }

    func getDeviceMute(_ deviceID: AudioDeviceID) throws -> Bool {
        guard let element = muteElement(for: deviceID) else {
            throw AudioHardwareError.propertyUnavailable("Input mute is not supported for device \(deviceID).")
        }

        let value: UInt32 = try read(
            objectID: deviceID,
            address: muteAddress(element: element),
            as: UInt32.self
        )

        return value != 0
    }

    func setDeviceMute(_ deviceID: AudioDeviceID, muted: Bool) throws {
        guard let element = muteElement(for: deviceID) else {
            throw AudioHardwareError.propertyUnavailable("Input mute is not supported for device \(deviceID).")
        }

        try write(
            objectID: deviceID,
            address: muteAddress(element: element),
            value: UInt32(muted ? 1 : 0)
        )
    }

    func deviceSupportsVolume(_ deviceID: AudioDeviceID) -> Bool {
        volumeElement(for: deviceID) != nil
    }

    func getInputVolume(_ deviceID: AudioDeviceID) throws -> Float32 {
        guard let element = volumeElement(for: deviceID) else {
            throw AudioHardwareError.propertyUnavailable("Input volume is not supported for device \(deviceID).")
        }

        return try read(
            objectID: deviceID,
            address: volumeAddress(element: element),
            as: Float32.self
        )
    }

    func setInputVolume(_ deviceID: AudioDeviceID, volume: Float32) throws {
        guard let element = volumeElement(for: deviceID) else {
            throw AudioHardwareError.propertyUnavailable("Input volume is not supported for device \(deviceID).")
        }

        try write(
            objectID: deviceID,
            address: volumeAddress(element: element),
            value: min(max(volume, 0), 1)
        )
    }

    func hasProperty(objectID: AudioObjectID, address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        return AudioObjectHasProperty(objectID, &address)
    }

    private var defaultInputDeviceAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private var processInputMuteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessInputMute,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private var nameAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func muteAddress(element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
    }

    private func volumeAddress(element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
    }

    private func muteElement(for deviceID: AudioDeviceID) -> AudioObjectPropertyElement? {
        propertyElement(
            for: deviceID,
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeInput
        )
    }

    private func volumeElement(for deviceID: AudioDeviceID) -> AudioObjectPropertyElement? {
        propertyElement(
            for: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeInput
        )
    }

    private func propertyElement(
        for deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> AudioObjectPropertyElement? {
        let candidates: [AudioObjectPropertyElement] = [
            kAudioObjectPropertyElementMain,
            1,
            2
        ]

        for element in candidates {
            let address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: scope,
                mElement: element
            )

            if hasProperty(objectID: deviceID, address: address) {
                return element
            }
        }

        return nil
    }

    private func read<T>(objectID: AudioObjectID, address: AudioObjectPropertyAddress, as type: T.Type) throws -> T {
        var address = address
        var value = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { value.deallocate() }
        var size = UInt32(MemoryLayout<T>.size)

        let status = AudioObjectGetPropertyData(
            objectID,
            &address,
            0,
            nil,
            &size,
            value
        )

        guard status == noErr else {
            throw AudioHardwareError.osStatus(status, context: "Read selector \(address.mSelector)")
        }

        return value.move()
    }

    private func write<T>(objectID: AudioObjectID, address: AudioObjectPropertyAddress, value: T) throws {
        var address = address
        var mutableValue = value
        let size = UInt32(MemoryLayout<T>.size)

        let status = AudioObjectSetPropertyData(
            objectID,
            &address,
            0,
            nil,
            size,
            &mutableValue
        )

        guard status == noErr else {
            throw AudioHardwareError.osStatus(status, context: "Write selector \(address.mSelector)")
        }
    }
}

enum AudioHardwareError: LocalizedError, Equatable {
    case noInputDevice
    case propertyUnavailable(String)
    case osStatus(OSStatus, context: String)

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "No input microphone is selected."
        case .propertyUnavailable(let description):
            return description
        case .osStatus(let status, let context):
            return "\(context) failed with OSStatus \(status)."
        }
    }
}
