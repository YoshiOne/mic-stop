import CoreAudio
import Foundation

struct MuteControllerStateSnapshot: Sendable {
    let desiredMuteState: MuteState
    let appliedDeviceState: MuteState
    let observedInputDevice: ObservedInputDevice
    let applyStrategy: MuteApplyStrategy
}

final class MicrophoneMuteController {
    var onStateChanged: ((MuteControllerStateSnapshot) -> Void)?

    private let audioHardware: AudioHardwareControlling
    private(set) var desiredMuteState: MuteState
    private(set) var appliedDeviceState: MuteState = .unmuted
    private(set) var observedInputDevice = ObservedInputDevice(id: nil, name: "Unknown Microphone")
    private(set) var currentApplyStrategy: MuteApplyStrategy = .unsupported
    private(set) var strategyCache: [AudioDeviceID: MuteApplyStrategy] = [:]
    private(set) var previousInputVolumes: [AudioDeviceID: Float32] = [:]

    var stateSnapshot: MuteControllerStateSnapshot {
        MuteControllerStateSnapshot(
            desiredMuteState: desiredMuteState,
            appliedDeviceState: appliedDeviceState,
            observedInputDevice: observedInputDevice,
            applyStrategy: currentApplyStrategy
        )
    }

    init(audioHardware: AudioHardwareControlling, initialDesiredMuteState: MuteState = .unmuted) {
        self.audioHardware = audioHardware
        self.desiredMuteState = initialDesiredMuteState
    }

    func toggleMute() throws {
        try setDesiredMute(desiredMuteState.toggled)
    }

    func mute() throws {
        try setDesiredMute(.muted)
    }

    func unmute() throws {
        try setDesiredMute(.unmuted)
    }

    func setDesiredMute(_ newState: MuteState) throws {
        desiredMuteState = newState
        try applyDesiredStateToCurrentDevice()
    }

    func applyTransientMuteState(_ state: MuteState) throws {
        let deviceID = try audioHardware.defaultInputDeviceID()
        let strategy = strategy(for: deviceID)
        try apply(strategy: strategy, to: deviceID, desiredState: state)
        try refreshObservedState()
    }

    func applyDesiredStateToCurrentDevice() throws {
        let deviceID = try audioHardware.defaultInputDeviceID()
        let strategy = strategy(for: deviceID)
        try apply(strategy: strategy, to: deviceID, desiredState: desiredMuteState)
        try refreshObservedState()
    }

    func handleDefaultInputDeviceChanged() throws {
        try applyDesiredStateToCurrentDevice()
    }

    func refreshObservedState() throws {
        let deviceID = try audioHardware.defaultInputDeviceID()
        let strategy = strategy(for: deviceID)
        let observedMuted = try observedMutedState(for: deviceID, strategy: strategy)

        currentApplyStrategy = strategy
        observedInputDevice = ObservedInputDevice(
            id: deviceID,
            name: audioHardware.deviceName(deviceID)
        )
        appliedDeviceState = observedMuted ? .muted : .unmuted
        emitState()
    }

    func strategy(for deviceID: AudioDeviceID) -> MuteApplyStrategy {
        if let cached = strategyCache[deviceID] {
            return cached
        }

        let strategy: MuteApplyStrategy
        if audioHardware.deviceSupportsMute(deviceID) {
            strategy = .deviceMute
        } else if audioHardware.deviceSupportsVolume(deviceID) {
            strategy = .volumeFallback
        } else if audioHardware.supportsProcessInputMute {
            strategy = .processMute
        } else {
            strategy = .unsupported
        }

        strategyCache[deviceID] = strategy
        return strategy
    }

    private func apply(strategy: MuteApplyStrategy, to deviceID: AudioDeviceID, desiredState: MuteState) throws {
        switch strategy {
        case .processMute:
            try audioHardware.setProcessInputMute(desiredState == .muted)
        case .deviceMute:
            try audioHardware.setDeviceMute(deviceID, muted: desiredState == .muted)
        case .volumeFallback:
            try applyVolumeFallback(to: deviceID, desiredState: desiredState)
        case .unsupported:
            throw AudioHardwareError.propertyUnavailable("The current microphone does not support mute control.")
        }
    }

    private func applyVolumeFallback(to deviceID: AudioDeviceID, desiredState: MuteState) throws {
        switch desiredState {
        case .muted:
            if previousInputVolumes[deviceID] == nil {
                previousInputVolumes[deviceID] = try audioHardware.getInputVolume(deviceID)
            }
            try audioHardware.setInputVolume(deviceID, volume: 0)
        case .unmuted:
            guard let previousVolume = previousInputVolumes[deviceID] else {
                try audioHardware.setInputVolume(deviceID, volume: 1)
                return
            }
            try audioHardware.setInputVolume(deviceID, volume: previousVolume)
            previousInputVolumes.removeValue(forKey: deviceID)
        }
    }

    private func observedMutedState(for deviceID: AudioDeviceID, strategy: MuteApplyStrategy) throws -> Bool {
        switch strategy {
        case .processMute:
            return try audioHardware.getProcessInputMute()
        case .deviceMute:
            return try audioHardware.getDeviceMute(deviceID)
        case .volumeFallback:
            return try audioHardware.getInputVolume(deviceID) <= 0.0001
        case .unsupported:
            return false
        }
    }

    private func emitState() {
        onStateChanged?(stateSnapshot)
    }
}
