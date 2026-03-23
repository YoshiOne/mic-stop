import AppKit
import SwiftUI

@main
struct MicStopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        settingsWindowController = SettingsWindowController(appState: appState)
        statusBarController = StatusBarController(
            appState: appState,
            openSettings: { [weak self] in
                self?.settingsWindowController?.show()
            }
        )
    }
}
