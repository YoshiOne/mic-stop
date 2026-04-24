import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var desiredMuteState: MuteState
    @Published private(set) var appliedDeviceState: MuteState
    @Published private(set) var currentDeviceName: String
    @Published private(set) var shortcut: AppShortcut
    @Published private(set) var hotkeyMode: HotkeyMode
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var lastError: String?
    @Published private(set) var shortcutRecorderError: String?
    @Published private(set) var currentApplyStrategy: MuteApplyStrategy

    private let defaultsStore: DefaultsStore
    private let muteController: MicrophoneMuteController
    private let hotkeyManager: any HotkeyManaging
    private let audioObserver: AudioDeviceObserver
    private let launchAtLoginManager: any LaunchAtLoginManaging
    private let nowProvider: () -> Date
    private let hotkeyDoublePressThreshold: TimeInterval

    private var lastHotkeyPressDate: Date?
    private var holdToTalkPressIsActive = false

    init(
        defaultsStore: DefaultsStore = DefaultsStore(),
        audioHardware: AudioHardwareControlling = SystemAudioHardwareController(),
        hotkeyManager: any HotkeyManaging = HotkeyManager(),
        launchAtLoginManager: any LaunchAtLoginManaging = LaunchAtLoginManager(),
        nowProvider: @escaping () -> Date = Date.init,
        hotkeyDoublePressThreshold: TimeInterval = 0.3
    ) {
        self.defaultsStore = defaultsStore
        self.shortcut = defaultsStore.loadShortcut()
        self.desiredMuteState = defaultsStore.loadDesiredMuteState()
        self.hotkeyMode = defaultsStore.loadHotkeyMode()
        self.appliedDeviceState = .unmuted
        self.currentDeviceName = "Unknown Microphone"
        self.currentApplyStrategy = .unsupported
        self.hotkeyManager = hotkeyManager
        self.launchAtLoginManager = launchAtLoginManager
        self.launchAtLoginEnabled = launchAtLoginManager.isEnabled
        self.nowProvider = nowProvider
        self.hotkeyDoublePressThreshold = hotkeyDoublePressThreshold

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

    var hotkeyModeBinding: Binding<HotkeyMode> {
        Binding(
            get: { [weak self] in
                self?.hotkeyMode ?? .toggle
            },
            set: { [weak self] mode in
                self?.setHotkeyMode(mode)
            }
        )
    }

    var toggleMenuTitle: String {
        if hotkeyMode == .holdToTalk {
            return "Hold Hotkey to Talk"
        }

        return desiredMuteState == .muted ? "Unmute Microphone" : "Mute Microphone"
    }

    var statusLine: String {
        "Desired: \(desiredMuteState.displayName), Applied: \(appliedDeviceState.displayName)"
    }

    var statusSummary: String {
        "\(appliedDeviceState.displayName) on \(currentDeviceName)"
    }

    var strategyLine: String {
        "Strategy: \(currentApplyStrategy.displayName)"
    }

    func toggleMute() {
        guard hotkeyMode == .toggle else {
            enforceHoldToTalkBaseline()
            return
        }

        do {
            try muteController.toggleMute()
            persistAndRefreshState()
        } catch {
            present(error)
        }
    }

    func updateShortcut(_ newShortcut: AppShortcut) {
        do {
            try hotkeyManager.updateShortcut(to: newShortcut)
            shortcut = newShortcut
            defaultsStore.saveShortcut(newShortcut)
            shortcutRecorderError = nil
            lastError = nil
        } catch {
            present(error)
        }
    }

    func presentShortcutValidationError(_ error: Error) {
        shortcutRecorderError = error.localizedDescription
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

    func setHotkeyMode(_ newMode: HotkeyMode) {
        guard hotkeyMode != newMode else {
            return
        }

        hotkeyMode = newMode
        holdToTalkPressIsActive = false

        if newMode == .holdToTalk {
            setPersistentMuteState(.muted)
            return
        }

        if appliedDeviceState != desiredMuteState {
            setPersistentMuteState(appliedDeviceState)
            return
        }

        persistAndRefreshState()
    }

    private func wireUpCallbacks() {
        hotkeyManager.onHotKeyPressed = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleHotkeyPressed()
            }
        }

        hotkeyManager.onHotKeyReleased = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleHotkeyReleased()
            }
        }

        muteController.onStateChanged = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.desiredMuteState = snapshot.desiredMuteState
                self?.appliedDeviceState = snapshot.appliedDeviceState
                self?.currentDeviceName = snapshot.observedInputDevice.name
                self?.currentApplyStrategy = snapshot.applyStrategy
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
            persistAndRefreshState()
        } catch {
            present(error)
        }
    }

    private func handleDefaultInputDeviceChange() {
        if hotkeyMode == .holdToTalk, holdToTalkPressIsActive {
            applyTransientMuteState(.unmuted)
            return
        }

        do {
            try muteController.handleDefaultInputDeviceChanged()
            persistAndRefreshState()
        } catch {
            present(error)
        }
    }

    private func persistAndRefreshState() {
        syncFromController()
        defaultsStore.saveDesiredMuteState(desiredMuteState)
        defaultsStore.saveHotkeyMode(hotkeyMode)
        lastError = nil
    }

    private func handleHotkeyPressed() {
        let now = nowProvider()

        if let previousPressDate = lastHotkeyPressDate,
           now.timeIntervalSince(previousPressDate) <= hotkeyDoublePressThreshold {
            lastHotkeyPressDate = nil
            toggleHotkeyMode()
            return
        }

        lastHotkeyPressDate = now

        switch hotkeyMode {
        case .toggle:
            toggleMute()
        case .holdToTalk:
            holdToTalkPressIsActive = true
            applyTransientMuteState(.unmuted)
        }
    }

    private func handleHotkeyReleased() {
        guard hotkeyMode == .holdToTalk, holdToTalkPressIsActive else {
            return
        }

        holdToTalkPressIsActive = false
        enforceHoldToTalkBaseline()
    }

    private func toggleHotkeyMode() {
        setHotkeyMode(hotkeyMode.toggled)
    }

    private func setPersistentMuteState(_ state: MuteState) {
        do {
            try muteController.setDesiredMute(state)
            persistAndRefreshState()
        } catch {
            present(error)
        }
    }

    private func applyTransientMuteState(_ state: MuteState) {
        do {
            try muteController.applyTransientMuteState(state)
            syncFromController()
            defaultsStore.saveDesiredMuteState(desiredMuteState)
            defaultsStore.saveHotkeyMode(hotkeyMode)
            lastError = nil
        } catch {
            present(error)
        }
    }

    private func enforceHoldToTalkBaseline() {
        holdToTalkPressIsActive = false
        setPersistentMuteState(.muted)
    }

    func flushPendingHotkeyAction() {
        // Toggle actions are applied immediately. Kept for test compatibility.
    }

    func simulateDefaultInputDeviceChangeForTesting() {
        handleDefaultInputDeviceChange()
    }

    private func syncFromController() {
        let snapshot = muteController.stateSnapshot
        desiredMuteState = snapshot.desiredMuteState
        appliedDeviceState = snapshot.appliedDeviceState
        currentDeviceName = snapshot.observedInputDevice.name
        currentApplyStrategy = snapshot.applyStrategy
        launchAtLoginEnabled = launchAtLoginManager.isEnabled
    }

    private func present(_ error: Error) {
        lastError = error.localizedDescription
        syncFromController()
    }
}
