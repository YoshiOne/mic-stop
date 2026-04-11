# Mic Stop

[![Swift Tests](https://github.com/YoshiOne/mic-stop/workflows/Swift%20Tests/badge.svg)](https://github.com/YoshiOne/mic-stop/actions/workflows/swift-tests.yml)

<p align="center">
  <img src="design/mic-stop-icon.svg" alt="Mic Stop app icon" width="160" height="160">
</p>

Mic Stop is a tiny menu bar utility for macOS that lets you mute or unmute your microphone with a global hotkey.

It stays out of the way, lives in the menu bar, and keeps your chosen mute state even if you switch from your MacBook mic to a Bluetooth headset or another input device.

## What It Does

- toggles your microphone from anywhere with a keyboard shortcut
- supports both `Toggle` and `Hold to Talk` hotkey modes
- lets you switch hotkey modes from Settings or by double-pressing the hotkey
- runs quietly in the menu bar without a Dock icon
- remembers your preferred hotkey
- remembers your preferred hotkey mode and mute baseline across launches
- follows microphone changes automatically
- can launch when you log in

## Hotkey Modes

- `Toggle`: one press flips between muted and live.
- `Hold to Talk`: Mic Stop keeps a safe muted baseline, temporarily unmutes while the hotkey is held, and remutes on release.

When you are in `Hold to Talk`, switching microphones keeps the muted baseline and re-applies the temporary live state if the key is still held.

## Requirements

- macOS Sequoia or newer

## Settings

The settings window includes:

- a shortcut recorder for changing the global hotkey
- a segmented control for choosing `Toggle` or `Hold to Talk`
- a launch-at-login switch
- live status cards for the current microphone, desired state, and applied state

## Running the App

If you want the proper macOS app experience, open `MicStop.xcodeproj` in Xcode and run the `MicStop` scheme.

If Xcode asks for signing, select your own Apple development team in the project settings.

## Running from Swift Package Manager

```bash
swift run --disable-sandbox MicStopApp
```

## Running Tests

```bash
swift test --disable-sandbox
```
