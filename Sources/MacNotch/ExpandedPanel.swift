import SwiftUI

enum Module: String, CaseIterable, Identifiable {
    case media, timer, tasks, buffer, screenTime, system
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .media: return "music.note"
        case .timer: return "timer"
        case .tasks: return "checklist"
        case .buffer: return "doc.on.clipboard"
        case .screenTime: return "hourglass"
        case .system: return "cpu"
        }
    }

    var name: String {
        switch self {
        case .media: return "Media"
        case .timer: return "Timer"
        case .tasks: return "Tasks"
        case .buffer: return "Buffer"
        case .screenTime: return "Screen Time"
        case .system: return "System"
        }
    }
}

/// Contents of the expanded brow: a horizontal icon rail plus the active module.
struct ExpandedPanel: View {
    @ObservedObject var state: NotchState
    @ObservedObject var settings: Settings
    let modules: AppModules
    let topInset: CGFloat

    /// The module to show — the selected one, unless it was disabled.
    private var current: Module {
        settings.isEnabled(state.currentModule)
            ? state.currentModule
            : (settings.enabledModules.first ?? .tasks)
    }

    var body: some View {
        VStack(spacing: 10) {
            rail
            Group {
                switch current {
                case .media: MediaPanel(media: modules.media)
                case .timer: PomodoroPanel(model: modules.pomodoro)
                case .tasks: TodoPanel(store: modules.todo, state: state)
                case .buffer: BufferPanel(manager: modules.buffer, state: state)
                case .screenTime: ScreenTimePanel(usage: modules.usage, state: state)
                case .system: SystemPanel(stats: modules.system)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.top, topInset + 8)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
    }

    private var rail: some View {
        HStack(spacing: 5) {
            ForEach(settings.enabledModules) { module in
                tab(module)
            }
            iconButton("gearshape.fill",
                       tint: Color(red: 0.980, green: 0.514, blue: 0.302), // #FA834D coral
                       help: "Settings") {
                modules.settingsWindow.toggle()
            }
            Button { NSApp.terminate(nil) } label: {
                Text("Quit")
                    .font(.system(size: 11, weight: .bold))
                    .frame(height: 32)
                    .padding(.horizontal, 12)
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Quit mac-notch")
        }
    }

    private func tab(_ module: Module) -> some View {
        let active = current == module
        return Button { state.selectModule(module) } label: {
            Image(systemName: module.icon)
                .font(.system(size: 13, weight: active ? .bold : .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .foregroundStyle(active ? .white : .white.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(active ? Color.white.opacity(0.24) : Color.white.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(active ? 0.35 : 0), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(module.name)
    }

    private func iconButton(_ icon: String, tint: Color, help: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 40, height: 32)
                .foregroundStyle(tint)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
