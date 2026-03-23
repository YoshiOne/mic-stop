import Carbon
import Foundation

final class HotkeyManager {
    var onHotKeyPressed: (() -> Void)?

    private static let signature: OSType = 0x4D44484B
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init() {
        installEventHandler()
    }

    deinit {
        unregister()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func register(shortcut: AppShortcut) throws {
        try shortcut.validate()
        unregister()

        var hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            throw HotkeyError.registrationFailed(status: status)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    func updateShortcut(to shortcut: AppShortcut) throws {
        try register(shortcut: shortcut)
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, eventRef, userData in
            guard let userData, let eventRef else {
                return noErr
            }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handleHotkey(eventRef)
        }

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
    }

    private func handleHotkey(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        if hotKeyID.signature == Self.signature {
            onHotKeyPressed?()
        }

        return noErr
    }
}

enum HotkeyError: LocalizedError {
    case registrationFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            return "Failed to register the global hotkey. OSStatus: \(status)."
        }
    }
}
