import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    private let panelBackground = Color(nsColor: NSColor.windowBackgroundColor).opacity(0.9)
    private let panelBorder = Color.white.opacity(0.08)
    private let accent = Color(red: 0.99, green: 0.34, blue: 0.33)

    var body: some View {
        ZStack {
            SettingsBackgroundView(accent: accent)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    overviewSection
                    controlsSection
                    statusSection

                    if let lastError = appState.lastError {
                        errorSection(lastError)
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 560, minHeight: 520)
    }

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accent.gradient)
                    .frame(width: 60, height: 60)

                Image(systemName: appState.desiredMuteState == .muted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Mic Stop")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    stateBadge(
                        title: appState.desiredMuteState.displayName,
                        systemImage: appState.desiredMuteState == .muted ? "speaker.slash.fill" : "waveform"
                    )
                }

                Text("Fast mute control with state persistence across microphone changes.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("Your hotkey, login behavior, and talk mode live here.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary.opacity(0.9))
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .background(cardBackground)
    }

    private var overviewSection: some View {
        HStack(spacing: 14) {
            InfoCard(
                title: "Current microphone",
                value: appState.currentDeviceName,
                detail: "Mic Stop reapplies your preferred state when this device changes.",
                systemImage: "mic.circle.fill",
                tint: accent
            )

            InfoCard(
                title: "Hotkey mode",
                value: appState.hotkeyMode.displayName,
                detail: appState.hotkeyMode == .toggle
                    ? "One press toggles mute on or off."
                    : "Hold the shortcut to temporarily speak.",
                systemImage: "keyboard.fill",
                tint: Color(red: 0.23, green: 0.64, blue: 0.98)
            )
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader("Controls", subtitle: "Tune how Mic Stop behaves on your Mac.")

            VStack(spacing: 14) {
                settingRow(
                    title: "Shortcut",
                    description: "Click the field and press a new key combination."
                ) {
                    VStack(alignment: .trailing, spacing: 8) {
                        ShortcutRecorderView(shortcut: appState.shortcut) { shortcut in
                            appState.updateShortcut(shortcut)
                        }
                        .frame(width: 220, height: 48)

                        Text("Use Command or Control for the most reliable global shortcut.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().overlay(Color.white.opacity(0.06))

                settingRow(
                    title: "Hotkey mode",
                    description: "Switch behavior directly from settings instead of double-pressing the shortcut."
                ) {
                    Picker("Hotkey mode", selection: appState.hotkeyModeBinding) {
                        ForEach(HotkeyMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                }

                Divider().overlay(Color.white.opacity(0.06))

                settingRow(
                    title: "Launch at login",
                    description: "Keep mute control ready as soon as you sign in."
                ) {
                    Toggle("", isOn: appState.launchAtLoginBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.large)
                }
            }
            .padding(18)
            .background(subtleCardBackground)
        }
        .padding(22)
        .background(cardBackground)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Status", subtitle: "Helpful at-a-glance diagnostics while testing microphone behavior.")

            HStack(spacing: 14) {
                statusPill(
                    title: "Desired",
                    value: appState.desiredMuteState.displayName,
                    tint: appState.desiredMuteState == .muted ? accent : Color(red: 0.17, green: 0.69, blue: 0.43)
                )

                statusPill(
                    title: "Applied",
                    value: appState.appliedDeviceState.displayName,
                    tint: appState.appliedDeviceState == .muted ? accent : Color(red: 0.17, green: 0.69, blue: 0.43)
                )
            }

            Text(appState.statusLine)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(cardBackground)
    }

    private func errorSection(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.38))
                .font(.system(size: 16, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Something needs attention")
                    .font(.system(size: 13, weight: .semibold))

                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.35, green: 0.12, blue: 0.11).opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 1.0, green: 0.45, blue: 0.38).opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(panelBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(panelBorder, lineWidth: 1)
            )
    }

    private var subtleCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private func settingRow<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 240, alignment: .leading)
            }

            Spacer(minLength: 12)
            content()
        }
    }

    private func stateBadge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    private func statusPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)

                Text(value)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct SettingsBackgroundView: View {
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor.windowBackgroundColor),
                    Color(nsColor: NSColor.controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 220, y: -180)

            Circle()
                .fill(Color(red: 0.18, green: 0.54, blue: 0.95).opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -220, y: 220)
        }
        .ignoresSafeArea()
    }
}

private struct InfoCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
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
        let path = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)

        let fillColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.18)
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
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
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
