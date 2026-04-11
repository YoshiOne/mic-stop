@testable import MicStopApp
import Foundation
import Testing

struct DefaultsStoreTests {
    @Test
    func hotkeyModeRoundTripsThroughDefaults() {
        let suiteName = "DefaultsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = DefaultsStore(defaults: defaults)
        store.saveHotkeyMode(.holdToTalk)

        #expect(store.loadHotkeyMode() == .holdToTalk)
    }
}
