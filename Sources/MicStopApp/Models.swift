import AppKit
import Carbon
import CoreAudio
import Foundation

enum MuteState: String, Codable, Sendable {
    case muted
    case unmuted

    var toggled: MuteState {
        self == .muted ? .unmuted : .muted
    }

    var displayName: String {
        self == .muted ? "Muted" : "Live"
    }
}

enum HotkeyMode: String, Codable, Sendable, CaseIterable {
    case toggle
    case holdToTalk

    var toggled: HotkeyMode {
        self == .toggle ? .holdToTalk : .toggle
    }

    var displayName: String {
        switch self {
        case .toggle:
            return "Toggle"
        case .holdToTalk:
            return "Hold to Talk"
        }
    }
}

enum MuteApplyStrategy: String, Codable, Sendable {
    case processMute
    case deviceMute
    case volumeFallback
    case unsupported
}

struct ObservedInputDevice: Equatable, Sendable {
    let id: AudioDeviceID?
    let name: String
}

struct AppShortcut: Codable, Hashable, Sendable {
    struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        let rawValue: UInt32

        static let command = Modifiers(rawValue: UInt32(cmdKey))
        static let option = Modifiers(rawValue: UInt32(optionKey))
        static let control = Modifiers(rawValue: UInt32(controlKey))
        static let shift = Modifiers(rawValue: UInt32(shiftKey))

        static let recommendedDefault: Modifiers = [.control, .option, .command]
    }

    enum ValidationError: LocalizedError {
        case missingModifiers
        case shiftOnly
        case optionShiftOnly

        var errorDescription: String? {
            switch self {
            case .missingModifiers:
                return "Choose a shortcut with at least one modifier key."
            case .shiftOnly:
                return "Shift-only shortcuts are too fragile for a global mute hotkey."
            case .optionShiftOnly:
                return "Option+Shift combinations are unreliable on macOS Sequoia. Add Command or Control."
            }
        }
    }

    let keyCode: UInt32
    let modifiers: Modifiers

    static let defaultShortcut = AppShortcut(
        unvalidatedKeyCode: UInt32(kVK_ANSI_M),
        modifiers: .recommendedDefault
    )

    init(keyCode: UInt32, modifiers: Modifiers) throws {
        self.keyCode = keyCode
        self.modifiers = modifiers
        try validate()
    }

    init(unvalidatedKeyCode keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiers = Modifiers(modifierFlags: modifierFlags)

        guard let shortcut = try? AppShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers) else {
            return nil
        }

        self = shortcut
    }

    var carbonModifiers: UInt32 {
        modifiers.rawValue
    }

    var displayString: String {
        modifiers.symbolString + keyDisplay
    }

    func validate() throws {
        if modifiers.isEmpty {
            throw ValidationError.missingModifiers
        }

        if modifiers == [.shift] {
            throw ValidationError.shiftOnly
        }

        if modifiers == [.option, .shift] {
            throw ValidationError.optionShiftOnly
        }
    }

    private var keyDisplay: String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
        case kVK_Space: "Space"
        case kVK_Return: "Return"
        case kVK_Escape: "Esc"
        default: "Key \(keyCode)"
        }
    }
}

extension AppShortcut.Modifiers {
    init(modifierFlags: NSEvent.ModifierFlags) {
        var value: Self = []

        if modifierFlags.contains(.command) {
            value.insert(.command)
        }

        if modifierFlags.contains(.option) {
            value.insert(.option)
        }

        if modifierFlags.contains(.control) {
            value.insert(.control)
        }

        if modifierFlags.contains(.shift) {
            value.insert(.shift)
        }

        self = value
    }

    var symbolString: String {
        var result = ""

        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }

        return result
    }
}
