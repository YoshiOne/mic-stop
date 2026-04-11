import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow

    init(appState: AppState) {
        let hostingController = NSHostingController(rootView: SettingsView(appState: appState))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Mic Stop Settings"
        window.setContentSize(NSSize(width: 620, height: 560))
        window.minSize = NSSize(width: 560, height: 520)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()

        self.window = window
        super.init()
        self.window.delegate = self
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
