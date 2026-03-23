import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let appState: AppState
    private let openSettingsHandler: () -> Void
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let iconHostingView = NSHostingView(rootView: StatusBarIconView(desiredMuteState: .unmuted))
    private var cancellables: Set<AnyCancellable> = []

    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleMute), keyEquivalent: "")
    private let microphoneItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let shortcutItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let statusItemLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let errorItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
    private let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")

    init(appState: AppState, openSettings: @escaping () -> Void) {
        self.appState = appState
        self.openSettingsHandler = openSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        configureMenu()
        bindState()
        refreshUI()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        button.image = nil
        button.title = ""
        button.addSubview(iconHostingView)
        iconHostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconHostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            iconHostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            iconHostingView.topAnchor.constraint(equalTo: button.topAnchor),
            iconHostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        statusItem.menu = menu
    }

    private func configureMenu() {
        toggleItem.target = self
        launchAtLoginItem.target = self
        settingsItem.target = self
        quitItem.target = self

        microphoneItem.isEnabled = false
        shortcutItem.isEnabled = false
        statusItemLine.isEnabled = false
        errorItem.isEnabled = false

        menu.items = [
            toggleItem,
            .separator(),
            microphoneItem,
            shortcutItem,
            statusItemLine,
            errorItem,
            .separator(),
            launchAtLoginItem,
            settingsItem,
            .separator(),
            quitItem
        ]
    }

    private func bindState() {
        appState.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshUI()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshUI() {
        iconHostingView.rootView = StatusBarIconView(desiredMuteState: appState.desiredMuteState)

        toggleItem.title = appState.toggleMenuTitle
        microphoneItem.title = "Microphone: \(appState.currentDeviceName)"
        shortcutItem.title = "Hotkey: \(appState.shortcut.displayString)"
        statusItemLine.title = appState.statusLine

        launchAtLoginItem.state = appState.launchAtLoginEnabled ? .on : .off

        if let error = appState.lastError, !error.isEmpty {
            errorItem.isHidden = false
            errorItem.title = error
        } else {
            errorItem.isHidden = true
            errorItem.title = ""
        }
    }

    @objc private func toggleMute() {
        appState.toggleMute()
        refreshUI()
    }

    @objc private func toggleLaunchAtLogin() {
        appState.setLaunchAtLogin(!appState.launchAtLoginEnabled)
        refreshUI()
    }

    @objc private func openSettings() {
        openSettingsHandler()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private struct StatusBarIconView: View {
    let desiredMuteState: MuteState

    var body: some View {
        Image(systemName: desiredMuteState == .muted ? "mic.slash.fill" : "mic.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(desiredMuteState == .muted ? Color.primary : .white)
            .padding(.horizontal, desiredMuteState == .muted ? 0 : 6)
            .padding(.vertical, desiredMuteState == .muted ? 0 : 2)
            .background {
                if desiredMuteState == .unmuted {
                    Capsule(style: .continuous)
                        .fill(Color.red)
                }
            }
            .frame(minWidth: desiredMuteState == .muted ? 18 : 28, minHeight: 18)
            .padding(.horizontal, 2)
    }
}
