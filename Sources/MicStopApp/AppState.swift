import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var desiredMuteState: MuteState
    @Published private(set) var appliedDeviceState: MuteState
    @Published private(set) var currentDeviceName: String
    @Published private(set) var shortcut: AppShortcut
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var lastError: String?

    private let defaultsStore: DefaultsStore
    private let muteController: MicrophoneMuteController
    private let hotkeyManager: HotkeyManager
    private let audioObserver: AudioDeviceObserver
    private let launchAtLoginManager: LaunchAtLoginManager

    init(
        defaultsStore: DefaultsStore = DefaultsStore(),
        audioHardware: AudioHardwareControlling = SystemAudioHardwareController(),
        hotkeyManager: HotkeyManager = HotkeyManager(),
        launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager()
    ) {
        self.defaultsStore = defaultsStore
        self.shortcut = defaultsStore.loadShortcut()
        self.desiredMuteState = defaultsStore.loadDesiredMuteState()
        self.appliedDeviceState = .unmuted
        self.currentDeviceName = "Unknown Microphone"
        self.hotkeyManager = hotkeyManager
        self.launchAtLoginManager = launchAtLoginManager
        self.launchAtLoginEnabled = launchAtLoginManager.isEnabled

        self.muteController = MicrophoneMuteController(
            audioHardware: audioHardware,
            initialDesiredMuteState: defaultsStore.loadDesiredMuteState()
        )

        self.audioObserver = AudioDeviceObserver(
            audioHardware: audioHardware,
            onDefaultInputDeviceChanged: {},
            onObservedInputPropertyChanged: {}
        )

        wireUpCallbacks()
        installHotkey()
        configureLaunchAtLogin()
        startObservation()
        restoreDesiredState()
    }

    var menuBarSymbolName: String {
        desiredMuteState == .muted ? "mic.slash.fill" : "mic.fill"
    }

    var menuBarSymbolColor: Color {
        desiredMuteState == .muted ? .primary : .white
    }

    var menuBarBackgroundColor: Color {
        desiredMuteState == .muted ? .clear : .red
    }

    var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.launchAtLoginEnabled ?? false
            },
            set: { [weak self] enabled in
                self?.setLaunchAtLogin(enabled)
            }
        )
    }

    var toggleMenuTitle: String {
        desiredMuteState == .muted ? "Unmute Microphone" : "Mute Microphone"
    }

    var statusLine: String {
        "Desired: \(desiredMuteState.displayName), Applied: \(appliedDeviceState.displayName)"
    }

    func toggleMute() {
        do {
            try muteController.toggleMute()
            persistAndRefresh()
        } catch {
            present(error)
        }
    }

    func updateShortcut(_ newShortcut: AppShortcut) {
        do {
            try hotkeyManager.updateShortcut(to: newShortcut)
            shortcut = newShortcut
            defaultsStore.saveShortcut(newShortcut)
            lastError = nil
        } catch {
            present(error)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginManager.setEnabled(enabled)
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
            defaultsStore.markLaunchAtLoginInitialized()
            lastError = nil
        } catch {
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
            present(error)
        }
    }

    func refreshState() {
        do {
            try muteController.refreshObservedState()
            syncFromController()
            lastError = nil
        } catch {
            present(error)
        }
    }

    private func wireUpCallbacks() {
        hotkeyManager.onHotKeyPressed = { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggleMute()
            }
        }

        muteController.onStateChanged = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.desiredMuteState = snapshot.desiredMuteState
                self?.appliedDeviceState = snapshot.appliedDeviceState
                self?.currentDeviceName = snapshot.observedInputDevice.name
            }
        }

        audioObserver.onDefaultInputDeviceChanged = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleDefaultInputDeviceChange()
            }
        }

        audioObserver.onObservedInputPropertyChanged = { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshState()
            }
        }
    }

    private func installHotkey() {
        do {
            try hotkeyManager.register(shortcut: shortcut)
            lastError = nil
        } catch {
            present(error)
        }
    }

    private func configureLaunchAtLogin() {
        if defaultsStore.shouldInitializeLaunchAtLogin {
            do {
                try launchAtLoginManager.setEnabled(true)
                defaultsStore.markLaunchAtLoginInitialized()
            } catch {
                present(error)
            }
        }

        launchAtLoginEnabled = launchAtLoginManager.isEnabled
    }

    private func startObservation() {
        audioObserver.start()
    }

    private func restoreDesiredState() {
        do {
            try muteController.applyDesiredStateToCurrentDevice()
            persistAndRefresh()
        } catch {
            present(error)
        }
    }

    private func handleDefaultInputDeviceChange() {
        do {
            try muteController.handleDefaultInputDeviceChanged()
            persistAndRefresh()
        } catch {
            present(error)
        }
    }

    private func persistAndRefresh() {
        syncFromController()
        defaultsStore.saveDesiredMuteState(desiredMuteState)
        lastError = nil
    }

    private func syncFromController() {
        let snapshot = muteController.stateSnapshot
        desiredMuteState = snapshot.desiredMuteState
        appliedDeviceState = snapshot.appliedDeviceState
        currentDeviceName = snapshot.observedInputDevice.name
        launchAtLoginEnabled = launchAtLoginManager.isEnabled
    }

    private func present(_ error: Error) {
        lastError = error.localizedDescription
        syncFromController()
    }
}
