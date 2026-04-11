# AGENTS.md

## Project Overview

`Mic Stop` is a macOS menu bar utility for macOS Sequoia+ that controls microphone mute for the active system input device, supports both toggle and hold-to-talk interaction, and keeps the user's intended mute baseline when the active microphone changes.

The repo intentionally keeps two entry paths:

- Swift Package for lightweight local builds and tests
- Xcode project for building a real `.app` bundle with proper login-item behavior

## Important Paths

- Swift package manifest: `Package.swift`
- App sources: `Sources/MicStopApp`
- Tests: `Tests/MicStopAppTests`
- Xcode project: `MicStop.xcodeproj`
- App bundle metadata: `MicStop/Info.plist`

## Architecture Notes

- `MicStopApp.swift` wires the app delegate and settings scene.
- `StatusBarController.swift` owns the `NSStatusItem` menu bar UI. Use this instead of `MenuBarExtra`; the project moved away from `MenuBarExtra` because menu bar template rendering prevented reliable custom coloring/backgrounds.
- `AppState.swift` is the main UI-facing state container and coordinator.
- `MicrophoneMuteController.swift` owns mute application logic and the "desired mute state" model.
- `DefaultsStore.swift` persists the shortcut, desired mute state, hotkey mode, and first-run launch-at-login initialization.
- `HotkeyManager.swift` listens for both hotkey press and hotkey release events; release handling matters for hold-to-talk.
- `AudioHardware.swift` wraps Core Audio / HAL interactions.
- `AudioDeviceObserver.swift` listens for default input device changes and relevant property updates.
- `SettingsView.swift` and `SettingsWindowController.swift` implement the settings UI/window.
- `Models.swift` contains the `HotkeyMode` model alongside the mute-state and shortcut types.

## Mute Logic Rules

- Do not treat `kAudioHardwarePropertyProcessInputMute` as the primary mute path for "all apps".
- Current intended priority is:
  1. device mute
  2. input volume fallback to `0`
  3. process input mute only as a last fallback
- `desiredMuteState` is the source of truth for user intent and must survive microphone switches.
- When the default input device changes, the app should immediately re-apply `desiredMuteState` to the new device.
- In `holdToTalk`, the persisted baseline must stay `muted`; temporary unmute while the key is held must not overwrite that baseline.
- If the input device changes during an active hold-to-talk press, the newly active device should become live immediately, but the app must still fall back to the muted baseline on release.
- Keep per-device cached previous input volumes so unmute restores the prior level for the correct microphone.

## UI Rules

- Muted state: regular white slashed mic icon in the menu bar.
- Live state: white mic icon on a colored background capsule.
- Hold-to-talk mode adds a small hand badge in the menu bar and uses distinct gray/orange capsule colors for muted/live transient states.
- The status menu exposes current microphone, shortcut, current mode, a double-press mode-switch hint, and the desired/applied diagnostic line.
- Settings are opened through the custom AppKit window controller, not via `showSettingsWindow:`. Avoid reintroducing the older SwiftUI settings-opening path that triggers warnings.
- The current settings window is a richer SwiftUI dashboard with shortcut capture, hotkey mode selection, launch-at-login control, and status/error cards.

## Build And Test

- Swift package run: `swift run --disable-sandbox MicStopApp`
- Swift package test: `swift test --disable-sandbox`
- Preferred packaging and manual QA: open `MicStop.xcodeproj` in Xcode and run the `MicStop` scheme.
- GitHub Actions CI lives at `.github/workflows/swift-tests.yml` and runs `swift test --disable-sandbox` on pushes to `master` and pull requests targeting `master`.
- `README.md` includes a workflow badge for `Swift Tests`; keep the workflow file name and badge URL aligned if the workflow is renamed.

## Test Coverage Notes

- `AppStateTests.swift` covers hotkey mode switching, double-press behavior, hold-to-talk press/release flow, and device-switch handling while pressed.
- `DefaultsStoreTests.swift` covers hotkey mode persistence.
- `MicrophoneMuteControllerTests.swift` covers mute strategy priority and per-device input-volume restoration.

## Change Discipline

- If you add files under `Sources/MicStopApp` or `Tests/MicStopAppTests`, also update `MicStop.xcodeproj` so the Xcode app target and test target stay in sync.
- Preserve support for macOS 15+.
- Prefer small, targeted changes; this app is compact and state coupling is mostly around `AppState`, `StatusBarController`, and `MicrophoneMuteController`.
