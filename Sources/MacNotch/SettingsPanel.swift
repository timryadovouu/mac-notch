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
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
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
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    let buffer: BufferManager

    var body: some View {
        Form {
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
                    ForEach(Module.allCases) { module in
                        Text(module.name).tag(module.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 340)
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
