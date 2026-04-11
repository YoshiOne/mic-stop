import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Mic Stop")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Mute your system microphone from anywhere and keep that state when the active microphone changes.")
                .foregroundStyle(.secondary)

            HStack {
                Text("Current microphone")
                Spacer()
                Text(appState.currentDeviceName)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Shortcut")
                Spacer()
                ShortcutRecorderView(shortcut: appState.shortcut) { shortcut in
                    appState.updateShortcut(shortcut)
                }
                .frame(width: 180, height: 34)
            }

            HStack(alignment: .top) {
                Text("Hotkey mode")
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(appState.hotkeyMode.displayName)
                    Text("Double-press the hotkey to switch between Toggle and Hold to Talk.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 240, alignment: .trailing)
                }
            }

            Toggle("Launch at Login", isOn: appState.launchAtLoginBinding)

            Text(appState.statusLine)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let lastError = appState.lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(20)
    }
}

struct ShortcutRecorderView: NSViewRepresentable {
    let shortcut: AppShortcut
    let onShortcutRecorded: (AppShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.shortcut = shortcut
        view.onShortcutRecorded = onShortcutRecorded
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.shortcut = shortcut
        nsView.onShortcutRecorded = onShortcutRecorded
    }
}

final class ShortcutRecorderNSView: NSView {
    var shortcut: AppShortcut = .defaultShortcut {
        didSet { needsDisplay = true }
    }

    var onShortcutRecorded: ((AppShortcut) -> Void)?

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

        guard let shortcut = AppShortcut(event: event) else {
            NSSound.beep()
            return
        }

        self.shortcut = shortcut
        isRecording = false
        onShortcutRecorded?(shortcut)
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)

        let backgroundColor = NSColor.controlBackgroundColor
        backgroundColor.setFill()
        path.fill()

        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "Press shortcut" : shortcut.displayString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
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
