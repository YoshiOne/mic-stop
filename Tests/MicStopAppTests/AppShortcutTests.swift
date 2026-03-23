import AppKit
import Carbon
@testable import MicStopApp
import Testing

struct AppShortcutTests {
    @Test
    func shortcutRoundTripsThroughCodable() throws {
        let shortcut = try AppShortcut(
            keyCode: UInt32(kVK_ANSI_M),
            modifiers: [.command, .option, .control]
        )

        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(AppShortcut.self, from: data)

        #expect(decoded == shortcut)
    }

    @Test
    func rejectsOptionShiftOnlyCombination() throws {
        #expect(throws: AppShortcut.ValidationError.optionShiftOnly) {
            try AppShortcut(
                keyCode: UInt32(kVK_ANSI_M),
                modifiers: [.option, .shift]
            )
        }
    }
}
