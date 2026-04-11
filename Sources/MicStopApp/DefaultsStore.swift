import Foundation

final class DefaultsStore {
    private enum Keys {
        static let shortcut = "shortcut"
        static let desiredMuteState = "desiredMuteState"
        static let hotkeyMode = "hotkeyMode"
        static let launchAtLoginInitialized = "launchAtLoginInitialized"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadShortcut() -> AppShortcut {
        guard
            let data = defaults.data(forKey: Keys.shortcut),
            let shortcut = try? JSONDecoder().decode(AppShortcut.self, from: data)
        else {
            return .defaultShortcut
        }

        return shortcut
    }

    func saveShortcut(_ shortcut: AppShortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else {
            return
        }

        defaults.set(data, forKey: Keys.shortcut)
    }

    func loadDesiredMuteState() -> MuteState {
        guard
            let rawValue = defaults.string(forKey: Keys.desiredMuteState),
            let state = MuteState(rawValue: rawValue)
        else {
            return .unmuted
        }

        return state
    }

    func saveDesiredMuteState(_ state: MuteState) {
        defaults.set(state.rawValue, forKey: Keys.desiredMuteState)
    }

    func loadHotkeyMode() -> HotkeyMode {
        guard
            let rawValue = defaults.string(forKey: Keys.hotkeyMode),
            let mode = HotkeyMode(rawValue: rawValue)
        else {
            return .toggle
        }

        return mode
    }

    func saveHotkeyMode(_ mode: HotkeyMode) {
        defaults.set(mode.rawValue, forKey: Keys.hotkeyMode)
    }

    var shouldInitializeLaunchAtLogin: Bool {
        defaults.object(forKey: Keys.launchAtLoginInitialized) == nil
    }

    func markLaunchAtLoginInitialized() {
        defaults.set(true, forKey: Keys.launchAtLoginInitialized)
    }
}
