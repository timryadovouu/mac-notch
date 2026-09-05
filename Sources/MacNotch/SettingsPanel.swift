import SwiftUI
import AppKit

/// Opens the settings as a normal, standalone window (not inside the notch).
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: Settings
    private let buffer: BufferManager
    private let claude: ClaudeSessionsManager

    init(settings: Settings, buffer: BufferManager, claude: ClaudeSessionsManager) {
        self.settings = settings
        self.buffer = buffer
        self.claude = claude
    }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 460),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.title = "mac-notch Settings"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(
                rootView: SettingsView(settings: settings, buffer: buffer, claude: claude)
            )
            // Place it below the expanded notch so opening it from the notch
            // doesn't overlap the panel.
            if let screen = NSScreen.main {
                let f = screen.frame
                let x = f.midX - w.frame.width / 2
                let y = f.maxY - (NotchRootView.panelHeight + 40) - w.frame.height
                w.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                w.center()
            }
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Open the settings window, or hide it if it's already showing.
    func toggle() {
        if let w = window, w.isVisible {
            w.orderOut(nil)
        } else {
            show()
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    let buffer: BufferManager
    let claude: ClaudeSessionsManager

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Track Claude Code sessions", isOn: $settings.trackClaude)
                    .onChange(of: settings.trackClaude) { on in if on { claude.installHooks() } }
            }

            Section("Modules") {
                ForEach(settings.orderedModules) { module in
                    moduleRow(module)
                }
            }

            Section("Timer") {
                Stepper(value: $settings.shortBreakMinutes, in: 1...60) {
                    Text("Short break: \(settings.shortBreakMinutes) min")
                }
                Stepper(value: $settings.longBreakMinutes, in: 1...60) {
                    Text("Long break: \(settings.longBreakMinutes) min")
                }
                Toggle("Play sound when a session ends", isOn: $settings.pomodoroSound)
                if settings.pomodoroSound {
                    soundList
                    Toggle("Play sound during Do Not Disturb / Focus", isOn: $settings.soundDuringDND)
                }
            }

            Section("Screen Time") {
                Picker("Keep history", selection: $settings.screenTimeRetentionDays) {
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("180 days").tag(180)
                    Text("1 year").tag(365)
                    Text("2 years").tag(730)
                    Text("Unlimited").tag(100_000)
                }
            }

            Section("Buffer") {
                HStack {
                    Text("Folder")
                    Spacer()
                    Text(settings.bufferRootPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 200, alignment: .trailing)
                    Button("Change…", action: pickFolder)
                }
                Stepper(value: $settings.bufferRetentionDays, in: 1...90) {
                    Text("Clear buffer older than \(settings.bufferRetentionDays) days")
                }
                .onChange(of: settings.bufferRetentionDays) { _ in buffer.applySettings() }
                .disabled(settings.clearBufferAtEndOfDay)

                Toggle("Delete each day's buffer at end of day", isOn: $settings.clearBufferAtEndOfDay)
                    .onChange(of: settings.clearBufferAtEndOfDay) { _ in buffer.applySettings() }
            }

            Section("Notch") {
                Stepper(value: $settings.recallMinutes, in: 1...240, step: 5) {
                    Text("Reset to default tab after \(settings.recallMinutes) min")
                }
                Picker("Default tab", selection: $settings.defaultModuleRaw) {
                    ForEach(settings.enabledModules) { module in
                        Text(module.name).tag(module.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 440)
    }

    private var soundList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sound — hover to preview")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(SystemSounds.available, id: \.self) { soundRow($0) }
                }
                .padding(2)
            }
            .frame(height: 132)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1)))
        }
    }

    private func soundRow(_ name: String) -> some View {
        let selected = settings.pomodoroSoundName == name
        return HStack(spacing: 8) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.5))
            Text(name).font(.system(size: 12))
            Spacer()
        }
        .padding(.vertical, 3).padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 5)
            .fill(selected ? Color.accentColor.opacity(0.18) : Color.clear))
        .contentShape(Rectangle())
        .onHover { if $0 { SystemSounds.preview(name) } }
        .onTapGesture { settings.pomodoroSoundName = name; SystemSounds.preview(name) }
    }

    private func moduleRow(_ module: Module) -> some View {
        HStack(spacing: 8) {
            Image(systemName: module.icon).frame(width: 18)
            Text(module.name)
            Spacer()
            Button { settings.moveModule(module, up: true) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless)
                .disabled(settings.moduleOrder.first == module.rawValue)
            Button { settings.moveModule(module, up: false) } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless)
                .disabled(settings.moduleOrder.last == module.rawValue)
            Toggle("", isOn: Binding(
                get: { settings.isEnabled(module) },
                set: { settings.setModuleEnabled(module, $0) }
            ))
            .labelsHidden()
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = settings.bufferRoot
        if panel.runModal() == .OK, let url = panel.url {
            settings.bufferRootPath = url.path
            buffer.applySettings()
        }
    }
}
