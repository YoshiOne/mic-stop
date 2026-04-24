import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            controls
            Divider()
            status

            if let message = appState.shortcutRecorderError {
                messageRow(message, systemImage: "keyboard.badge.exclamationmark", tint: .orange)
            }

            if let message = appState.lastError {
                messageRow(message, systemImage: "exclamationmark.triangle.fill", tint: .red)
            }
        }
        .padding(24)
        .frame(width: 480, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: appState.appliedDeviceState == .muted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(appState.appliedDeviceState == .muted ? Color.secondary : Color.red)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Mic Stop")
                    .font(.system(size: 20, weight: .semibold))

                Text(appState.statusSummary)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingRow(title: "Shortcut") {
                ShortcutRecorderView(
                    shortcut: appState.shortcut,
                    onShortcutRecorded: { shortcut in
                        appState.updateShortcut(shortcut)
                    },
                    onValidationFailed: { error in
                        appState.presentShortcutValidationError(error)
                    }
                )
                .frame(width: 190, height: 40)
            }

            settingRow(title: "Mode") {
                Picker("Mode", selection: appState.hotkeyModeBinding) {
                    ForEach(HotkeyMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            settingRow(title: "Launch at login") {
                Toggle("", isOn: appState.launchAtLoginBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Status")
                .font(.system(size: 13, weight: .semibold))

            Text(appState.statusLine)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(appState.strategyLine)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func settingRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 130, alignment: .leading)

            Spacer(minLength: 12)
            content()
        }
        .frame(minHeight: 42)
    }

    private func messageRow(_ message: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    let shortcut: AppShortcut
    let onShortcutRecorded: (AppShortcut) -> Void
    let onValidationFailed: (Error) -> Void

    init(
        shortcut: AppShortcut,
        onShortcutRecorded: @escaping (AppShortcut) -> Void,
        onValidationFailed: @escaping (Error) -> Void = { _ in }
    ) {
        self.shortcut = shortcut
        self.onShortcutRecorded = onShortcutRecorded
        self.onValidationFailed = onValidationFailed
    }

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.shortcut = shortcut
        view.onShortcutRecorded = onShortcutRecorded
        view.onValidationFailed = onValidationFailed
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.shortcut = shortcut
        nsView.onShortcutRecorded = onShortcutRecorded
        nsView.onValidationFailed = onValidationFailed
    }
}

final class ShortcutRecorderNSView: NSView {
    var shortcut: AppShortcut = .defaultShortcut {
        didSet { needsDisplay = true }
    }

    var onShortcutRecorded: ((AppShortcut) -> Void)?
    var onValidationFailed: ((Error) -> Void)?

    private var isRecording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            return
        }

        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiers = AppShortcut.Modifiers(modifierFlags: modifierFlags)

        do {
            let shortcut = try AppShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            self.shortcut = shortcut
            isRecording = false
            onShortcutRecorded?(shortcut)
        } catch {
            NSSound.beep()
            onValidationFailed?(error)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)

        let fillColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.16)
            : NSColor.controlBackgroundColor.withAlphaComponent(0.72)
        fillColor.setFill()
        path.fill()

        let borderColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.9)
            : NSColor.separatorColor.withAlphaComponent(0.65)
        borderColor.setStroke()
        path.lineWidth = isRecording ? 1.5 : 1
        path.stroke()

        let text = isRecording ? "Press shortcut" : shortcut.displayString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let size = text.size(withAttributes: attributes)
        let origin = NSPoint(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2
        )
        text.draw(at: origin, withAttributes: attributes)
    }
}
