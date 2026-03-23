# AGENTS.md

## Project Overview

`Mic Stop` is a macOS menu bar utility for macOS Sequoia+ that toggles microphone mute for the active system input device and keeps the user's intended mute state when the active microphone changes.

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
- `AudioHardware.swift` wraps Core Audio / HAL interactions.
- `AudioDeviceObserver.swift` listens for default input device changes and relevant property updates.
- `SettingsView.swift` and `SettingsWindowController.swift` implement the settings UI/window.

## Mute Logic Rules

- Do not treat `kAudioHardwarePropertyProcessInputMute` as the primary mute path for "all apps".
- Current intended priority is:
  1. device mute
  2. input volume fallback to `0`
  3. process input mute only as a last fallback
- `desiredMuteState` is the source of truth for user intent and must survive microphone switches.
- When the default input device changes, the app should immediately re-apply `desiredMuteState` to the new device.
- Keep per-device cached previous input volumes so unmute restores the prior level for the correct microphone.

## UI Rules

- Muted state: regular white slashed mic icon in the menu bar.
- Live state: white mic icon on a colored background capsule.
- Settings are opened through the custom AppKit window controller, not via `showSettingsWindow:`. Avoid reintroducing the older SwiftUI settings-opening path that triggers warnings.

## Build And Test

- Swift package run: `swift run --disable-sandbox MicStopApp`
- Swift package test: `swift test --disable-sandbox`
- Preferred packaging and manual QA: open `MicStop.xcodeproj` in Xcode and run the `MicStop` scheme.

## Change Discipline

- If you add files under `Sources/MicStopApp` or `Tests/MicStopAppTests`, also update `MicStop.xcodeproj` so the Xcode app target and test target stay in sync.
- Preserve support for macOS 15+.
- Prefer small, targeted changes; this app is compact and state coupling is mostly around `AppState`, `StatusBarController`, and `MicrophoneMuteController`.
