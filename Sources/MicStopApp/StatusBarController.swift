import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let appState: AppState
    private let openSettingsHandler: () -> Void
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let iconHostingView = NSHostingView(rootView: StatusBarIconView(desiredMuteState: .unmuted, hotkeyMode: .toggle))
    private var cancellables: Set<AnyCancellable> = []

    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleMute), keyEquivalent: "")
    private let microphoneItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let shortcutItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let modeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let hintItem = NSMenuItem(title: "Double-press hotkey to switch modes", action: nil, keyEquivalent: "")
    private let summaryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let statusItemLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let strategyItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
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

        launchAtLoginItem.image = menuSymbolImage(named: "power.circle")
        settingsItem.image = menuSymbolImage(named: "gearshape")

        microphoneItem.isEnabled = false
        shortcutItem.isEnabled = false
        modeItem.isEnabled = false
        hintItem.isEnabled = false
        summaryItem.isEnabled = false
        statusItemLine.isEnabled = false
        strategyItem.isEnabled = false
        errorItem.isEnabled = false

        menu.items = [
            toggleItem,
            .separator(),
            summaryItem,
            microphoneItem,
            shortcutItem,
            modeItem,
            hintItem,
            statusItemLine,
            strategyItem,
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
        iconHostingView.rootView = StatusBarIconView(
            desiredMuteState: appState.appliedDeviceState,
            hotkeyMode: appState.hotkeyMode
        )

        toggleItem.title = appState.toggleMenuTitle
        toggleItem.isEnabled = appState.hotkeyMode == .toggle
        summaryItem.title = appState.statusSummary
        microphoneItem.title = "Microphone: \(appState.currentDeviceName)"
        shortcutItem.title = "Hotkey: \(appState.shortcut.displayString)"
        modeItem.title = "Mode: \(appState.hotkeyMode.displayName)"
        statusItemLine.title = appState.statusLine
        strategyItem.title = appState.strategyLine

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

    private func menuSymbolImage(named systemName: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        return NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }
}

private struct StatusBarIconView: View {
    let desiredMuteState: MuteState
    let hotkeyMode: HotkeyMode

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: desiredMuteState == .muted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(backgroundColor)
                )

            if hotkeyMode == .holdToTalk {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(
                        Circle()
                            .fill(Color.orange)
                    )
                    .offset(x: 2, y: 2)
            }
        }
        .frame(minWidth: 28, minHeight: 18)
        .padding(.horizontal, 2)
    }

    private var foregroundColor: Color {
        desiredMuteState == .muted ? .primary : .white
    }

    private var backgroundColor: Color {
        switch (hotkeyMode, desiredMuteState) {
        case (.toggle, .muted):
            return .clear
        case (.toggle, .unmuted):
            return .red
        case (.holdToTalk, .muted):
            return Color.gray.opacity(0.28)
        case (.holdToTalk, .unmuted):
            return .orange
        }
    }
}
