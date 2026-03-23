import CoreAudio
import Foundation

final class AudioDeviceObserver {
    var onDefaultInputDeviceChanged: (() -> Void)?
    var onObservedInputPropertyChanged: (() -> Void)?

    private let audioHardware: AudioHardwareControlling
    private let systemAudioHardware: SystemAudioHardwareController?
    private let queue = DispatchQueue(label: "MicStop.AudioDeviceObserver")
    private var currentObservedDeviceID: AudioDeviceID?
    private var isStarted = false

    private var systemListenerBlocks: [AudioObjectPropertySelector: AudioObjectPropertyListenerBlock] = [:]
    private var deviceListenerBlocks: [String: AudioObjectPropertyListenerBlock] = [:]

    init(
        audioHardware: AudioHardwareControlling,
        onDefaultInputDeviceChanged: @escaping () -> Void,
        onObservedInputPropertyChanged: @escaping () -> Void
    ) {
        self.audioHardware = audioHardware
        self.systemAudioHardware = audioHardware as? SystemAudioHardwareController
        self.onDefaultInputDeviceChanged = onDefaultInputDeviceChanged
        self.onObservedInputPropertyChanged = onObservedInputPropertyChanged
    }

    deinit {
        stop()
    }

    func start() {
        guard !isStarted, let systemAudioHardware else {
            return
        }

        isStarted = true
        addSystemListener(address: defaultInputDeviceAddress)

        if systemAudioHardware.supportsProcessInputMute {
            addSystemListener(address: processInputMuteAddress)
        }

        if let deviceID = try? audioHardware.defaultInputDeviceID() {
            attachDeviceListeners(deviceID: deviceID)
        }
    }

    func stop() {
        guard isStarted, let systemAudioHardware else {
            return
        }

        removeSystemListener(address: defaultInputDeviceAddress)

        if systemAudioHardware.supportsProcessInputMute {
            removeSystemListener(address: processInputMuteAddress)
        }

        if let currentObservedDeviceID {
            detachDeviceListeners(deviceID: currentObservedDeviceID)
        }

        isStarted = false
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

    private func deviceMuteAddress(element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
    }

    private func deviceVolumeAddress(element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
    }

    private func addSystemListener(address: AudioObjectPropertyAddress) {
        let selector = address.mSelector
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.handleSystemPropertyChange(selector)
        }

        systemListenerBlocks[selector] = block
        var mutableAddress = address
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &mutableAddress,
            queue,
            block
        )
    }

    private func removeSystemListener(address: AudioObjectPropertyAddress) {
        guard let block = systemListenerBlocks[address.mSelector] else {
            return
        }

        var mutableAddress = address
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &mutableAddress,
            queue,
            block
        )
        systemListenerBlocks.removeValue(forKey: address.mSelector)
    }

    private func attachDeviceListeners(deviceID: AudioDeviceID) {
        guard let systemAudioHardware else {
            return
        }

        if let currentObservedDeviceID, currentObservedDeviceID != deviceID {
            detachDeviceListeners(deviceID: currentObservedDeviceID)
        }

        currentObservedDeviceID = deviceID

        if systemAudioHardware.hasProperty(objectID: deviceID, address: deviceMuteAddress()) {
            addDeviceListener(deviceID: deviceID, address: deviceMuteAddress())
        }

        if systemAudioHardware.hasProperty(objectID: deviceID, address: deviceVolumeAddress()) {
            addDeviceListener(deviceID: deviceID, address: deviceVolumeAddress())
        }
    }

    private func detachDeviceListeners(deviceID: AudioDeviceID) {
        removeDeviceListener(deviceID: deviceID, address: deviceMuteAddress())
        removeDeviceListener(deviceID: deviceID, address: deviceVolumeAddress())
        currentObservedDeviceID = nil
    }

    private func addDeviceListener(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) {
        let key = deviceListenerKey(deviceID: deviceID, selector: address.mSelector)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.notifyObservedInputPropertyChanged()
        }

        deviceListenerBlocks[key] = block
        var mutableAddress = address
        AudioObjectAddPropertyListenerBlock(deviceID, &mutableAddress, queue, block)
    }

    private func removeDeviceListener(deviceID: AudioDeviceID, address: AudioObjectPropertyAddress) {
        let key = deviceListenerKey(deviceID: deviceID, selector: address.mSelector)
        guard let block = deviceListenerBlocks[key] else {
            return
        }

        var mutableAddress = address
        AudioObjectRemovePropertyListenerBlock(deviceID, &mutableAddress, queue, block)
        deviceListenerBlocks.removeValue(forKey: key)
    }

    private func handleSystemPropertyChange(_ selector: AudioObjectPropertySelector) {
        if selector == kAudioHardwarePropertyDefaultInputDevice {
            if let deviceID = try? audioHardware.defaultInputDeviceID() {
                attachDeviceListeners(deviceID: deviceID)
            }
            onDefaultInputDeviceChanged?()
        } else {
            notifyObservedInputPropertyChanged()
        }
    }

    private func notifyObservedInputPropertyChanged() {
        onObservedInputPropertyChanged?()
    }

    private func deviceListenerKey(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String {
        "\(deviceID)-\(selector)"
    }
}
