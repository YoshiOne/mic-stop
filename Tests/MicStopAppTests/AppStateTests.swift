@testable import MicStopApp
import Foundation
import Testing

@MainActor
struct AppStateTests {
    @Test
    func defaultModeIsToggle() {
        let context = makeContext()

        let appState = makeAppState(context: context)

        #expect(appState.hotkeyMode == .toggle)
    }

    @Test
    func persistedModeRestoresOnLaunch() {
        let context = makeContext()
        context.defaultsStore.saveHotkeyMode(.holdToTalk)
        context.defaultsStore.saveDesiredMuteState(.muted)

        let appState = makeAppState(context: context)

        #expect(appState.hotkeyMode == .holdToTalk)
        #expect(appState.desiredMuteState == .muted)
    }

    @Test
    func switchingToHoldToTalkImmediatelyMutes() async {
        let context = makeContext(initialMuteState: .unmuted)
        let appState = makeAppState(context: context)

        context.hotkeyManager.simulatePress()
        await settleMainActor()
        context.clock.advance(by: 0.1)
        context.hotkeyManager.simulatePress()
        await settleMainActor()

        #expect(appState.hotkeyMode == .holdToTalk)
        #expect(appState.desiredMuteState == .muted)
        #expect(context.audio.deviceMuteByDevice[context.audio.defaultInputDeviceIDStorage] == true)
        #expect(context.defaultsStore.loadHotkeyMode() == .holdToTalk)
    }

    @Test
    func holdToTalkPressUnmutesAndReleaseRemutes() async {
        let context = makeContext(initialMode: .holdToTalk, initialMuteState: .muted)
        let appState = makeAppState(context: context)

        context.hotkeyManager.simulatePress()
        await settleMainActor()
        #expect(appState.desiredMuteState == .muted)
        #expect(appState.appliedDeviceState == .unmuted)
        #expect(context.audio.deviceMuteByDevice[context.audio.defaultInputDeviceIDStorage] == false)
        #expect(context.defaultsStore.loadDesiredMuteState() == .muted)

        context.hotkeyManager.simulateRelease()
        await settleMainActor()
        #expect(appState.desiredMuteState == .muted)
        #expect(appState.appliedDeviceState == .muted)
        #expect(context.audio.deviceMuteByDevice[context.audio.defaultInputDeviceIDStorage] == true)
        #expect(context.defaultsStore.loadDesiredMuteState() == .muted)
    }

    @Test
    func toggleModeIgnoresReleaseForMuteLogic() async {
        let context = makeContext(initialMuteState: .muted)
        let appState = makeAppState(context: context)

        context.hotkeyManager.simulatePress()
        await settleMainActor()
        #expect(appState.desiredMuteState == .unmuted)

        context.hotkeyManager.simulateRelease()
        await settleMainActor()
        #expect(appState.desiredMuteState == .unmuted)
    }

    @Test
    func doublePressSwitchesModeWithoutRunningPendingToggle() async {
        let context = makeContext(initialMuteState: .muted)
        let appState = makeAppState(context: context)

        context.hotkeyManager.simulatePress()
        await settleMainActor()
        #expect(appState.desiredMuteState == .unmuted)

        context.clock.advance(by: 0.1)
        context.hotkeyManager.simulatePress()
        await settleMainActor()

        #expect(appState.hotkeyMode == .holdToTalk)
        #expect(appState.desiredMuteState == .muted)
    }

    @Test
    func doublePressFromHoldToTalkDoesNotLeaveMicLiveAfterRelease() async {
        let context = makeContext(initialMode: .holdToTalk, initialMuteState: .muted)
        let appState = makeAppState(context: context)

        context.hotkeyManager.simulatePress()
        await settleMainActor()
        #expect(appState.desiredMuteState == .muted)
        #expect(appState.appliedDeviceState == .unmuted)

        context.clock.advance(by: 0.1)
        context.hotkeyManager.simulatePress()
        await settleMainActor()
        #expect(appState.hotkeyMode == .toggle)
        #expect(appState.desiredMuteState == .unmuted)
        #expect(appState.appliedDeviceState == .unmuted)

        context.hotkeyManager.simulateRelease()
        await settleMainActor()
        #expect(appState.desiredMuteState == .unmuted)
    }

    @Test
    func relaunchAfterHeldPressRestoresMutedBaseline() async {
        let context = makeContext(initialMode: .holdToTalk, initialMuteState: .muted)
        let appState = makeAppState(context: context)

        context.hotkeyManager.simulatePress()
        await settleMainActor()
        #expect(appState.desiredMuteState == .muted)
        #expect(appState.appliedDeviceState == .unmuted)
        #expect(context.defaultsStore.loadDesiredMuteState() == .muted)

        let relaunched = makeAppState(context: context)

        #expect(relaunched.hotkeyMode == .holdToTalk)
        #expect(relaunched.desiredMuteState == .muted)
        #expect(relaunched.appliedDeviceState == .muted)
        #expect(context.audio.deviceMuteByDevice[context.audio.defaultInputDeviceIDStorage] == true)
    }

    @Test
    func switchingIntoHoldToTalkPersistsMutedBaseline() async {
        let context = makeContext(initialMode: .toggle, initialMuteState: .unmuted)
        let appState = makeAppState(context: context)

        context.hotkeyManager.simulatePress()
        await settleMainActor()
        context.clock.advance(by: 0.1)
        context.hotkeyManager.simulatePress()
        await settleMainActor()

        #expect(appState.hotkeyMode == .holdToTalk)
        #expect(appState.desiredMuteState == .muted)
        #expect(context.defaultsStore.loadDesiredMuteState() == .muted)
    }

    @Test
    func menuToggleInHoldToTalkCannotPersistUnmutedBaseline() async {
        let context = makeContext(initialMode: .holdToTalk, initialMuteState: .muted)
        let appState = makeAppState(context: context)

        context.hotkeyManager.simulatePress()
        await settleMainActor()
        #expect(appState.desiredMuteState == .muted)
        #expect(appState.appliedDeviceState == .unmuted)

        appState.toggleMute()

        #expect(appState.desiredMuteState == .muted)
        #expect(appState.appliedDeviceState == .muted)
        #expect(context.defaultsStore.loadDesiredMuteState() == .muted)
        #expect(context.audio.deviceMuteByDevice[context.audio.defaultInputDeviceIDStorage] == true)
    }

    @Test
    func deviceChangeInHoldToTalkReappliesMutedBaselineWhenNotPressed() async {
        let context = makeContext(initialMode: .holdToTalk, initialMuteState: .muted)
        let appState = makeAppState(context: context)

        context.audio.defaultInputDeviceIDStorage = 202
        appState.simulateDefaultInputDeviceChangeForTesting()

        #expect(appState.desiredMuteState == .muted)
        #expect(appState.appliedDeviceState == .muted)
        #expect(context.audio.deviceMuteByDevice[202] == true)
        #expect(context.defaultsStore.loadDesiredMuteState() == .muted)
    }

    @Test
    func deviceChangeInHoldToTalkKeepsMicLiveWhilePressIsActive() async {
        let context = makeContext(initialMode: .holdToTalk, initialMuteState: .muted)
        let appState = makeAppState(context: context)

        context.hotkeyManager.simulatePress()
        await settleMainActor()
        #expect(appState.desiredMuteState == .muted)
        #expect(appState.appliedDeviceState == .unmuted)
        #expect(context.audio.deviceMuteByDevice[101] == false)

        context.audio.defaultInputDeviceIDStorage = 202
        appState.simulateDefaultInputDeviceChangeForTesting()

        #expect(appState.desiredMuteState == .muted)
        #expect(appState.appliedDeviceState == .unmuted)
        #expect(context.audio.deviceMuteByDevice[202] == false)
        #expect(context.defaultsStore.loadDesiredMuteState() == .muted)
    }

    private func makeAppState(context: TestContext) -> AppState {
        AppState(
            defaultsStore: context.defaultsStore,
            audioHardware: context.audio,
            hotkeyManager: context.hotkeyManager,
            launchAtLoginManager: context.launchAtLoginManager,
            nowProvider: context.clock.now,
            hotkeyDoublePressThreshold: 0.3
        )
    }

    private func makeContext(
        initialMode: HotkeyMode = .toggle,
        initialMuteState: MuteState = .unmuted
    ) -> TestContext {
        let suiteName = "AppStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let defaultsStore = DefaultsStore(defaults: defaults)
        defaultsStore.saveHotkeyMode(initialMode)
        defaultsStore.saveDesiredMuteState(initialMuteState)
        defaultsStore.markLaunchAtLoginInitialized()

        let audio = MockAudioHardware()
        audio.deviceMuteSupported = true
        audio.defaultInputDeviceIDStorage = 101

        return TestContext(
            defaultsStore: defaultsStore,
            defaults: defaults,
            suiteName: suiteName,
            audio: audio,
            hotkeyManager: MockHotkeyManager(),
            launchAtLoginManager: MockLaunchAtLoginManager(),
            clock: TestClock()
        )
    }

    private func settleMainActor() async {
        await Task.yield()
        await Task.yield()
    }
}

private final class TestContext {
    let defaultsStore: DefaultsStore
    let defaults: UserDefaults
    let suiteName: String
    let audio: MockAudioHardware
    let hotkeyManager: MockHotkeyManager
    let launchAtLoginManager: MockLaunchAtLoginManager
    let clock: TestClock

    init(
        defaultsStore: DefaultsStore,
        defaults: UserDefaults,
        suiteName: String,
        audio: MockAudioHardware,
        hotkeyManager: MockHotkeyManager,
        launchAtLoginManager: MockLaunchAtLoginManager,
        clock: TestClock
    ) {
        self.defaultsStore = defaultsStore
        self.defaults = defaults
        self.suiteName = suiteName
        self.audio = audio
        self.hotkeyManager = hotkeyManager
        self.launchAtLoginManager = launchAtLoginManager
        self.clock = clock
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class MockHotkeyManager: HotkeyManaging {
    var onHotKeyPressed: (() -> Void)?
    var onHotKeyReleased: (() -> Void)?
    private(set) var registeredShortcut: AppShortcut?

    func register(shortcut: AppShortcut) throws {
        registeredShortcut = shortcut
    }

    func unregister() {
        registeredShortcut = nil
    }

    func updateShortcut(to shortcut: AppShortcut) throws {
        registeredShortcut = shortcut
    }

    func simulatePress() {
        onHotKeyPressed?()
    }

    func simulateRelease() {
        onHotKeyReleased?()
    }
}

private final class MockLaunchAtLoginManager: LaunchAtLoginManaging {
    var isEnabled = false

    func setEnabled(_ enabled: Bool) throws {
        isEnabled = enabled
    }
}

private final class TestClock {
    private(set) var current = Date(timeIntervalSinceReferenceDate: 0)

    func now() -> Date {
        current
    }

    func advance(by interval: TimeInterval) {
        current = current.addingTimeInterval(interval)
    }
}
