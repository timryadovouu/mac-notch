import SwiftUI
import AppKit

/// Opens the settings as a normal, standalone window (not inside the notch).
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: Settings
    private let buffer: BufferManager

    init(settings: Settings, buffer: BufferManager) {
        self.settings = settings
        self.buffer = buffer
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
                rootView: SettingsView(settings: settings, buffer: buffer)
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

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
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
