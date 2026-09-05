import SwiftUI

struct ScreenTimePanel: View {
    @ObservedObject var usage: AppUsageTracker
    @ObservedObject var state: NotchState
    @State private var offset = 0                 // 0 = today, -1 = yesterday…
    @State private var cached: DayStats? = nil     // loaded stats for a past day
    @State private var earliest = 0

    private var stats: DayStats {
        offset == 0 ? usage.today : (cached ?? .empty(dateFor(offset)))
    }

    var body: some View {
        VStack(spacing: 10) {
            dateHeader

            HStack {
                stat(title: "Total", value: formatDuration(stats.total))
                Spacer()
                stat(title: "Switches", value: "\(stats.switches)")
            }

            if stats.apps.isEmpty {
                Spacer()
                Text(offset == 0 ? "Tracking starts now" : "No activity that day")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 7) {
                        ForEach(stats.apps.prefix(8)) { row($0) }
                    }
                }
            }

            GrabberBar(state: state)
        }
        .onAppear { earliest = usage.earliestOffset() }
        .onChange(of: offset) { newOffset in
            cached = newOffset == 0 ? nil : usage.loadDay(offset: newOffset)
            earliest = usage.earliestOffset()
        }
    }

    // MARK: - Date header

    private var dateHeader: some View {
        HStack {
            navButton("chevron.left", enabled: offset > earliest) { offset -= 1 }
            Spacer()
            Text(dateLabel)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            navButton("chevron.right", enabled: offset < 0) { offset += 1 }
        }
    }

    private func navButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 24)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(enabled ? 0.8 : 0.25))
        .disabled(!enabled)
    }

    private var dateLabel: String {
        switch offset {
        case 0: return "Today"
        case -1: return "Yesterday"
        default:
            let f = DateFormatter(); f.dateFormat = "EEE, d MMM"
            return f.string(from: dateFor(offset))
        }
    }

    private func dateFor(_ o: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: o, to: Date()) ?? Date()
    }

    // MARK: - Rows

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).monospacedDigit()
        }
    }

    private func row(_ app: AppUsage) -> some View {
        let fraction = stats.total > 0 ? Double(app.seconds) / Double(stats.total) : 0
        return VStack(spacing: 3) {
            HStack(spacing: 7) {
                Group {
                    if let path = app.iconPath {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable()
                    } else {
                        Image(systemName: "app.dashed").resizable()
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(width: 16, height: 16)
                Text(app.name).font(.system(size: 12)).lineLimit(1)
                Spacer()
                Text(formatDuration(app.seconds))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Color(red: 0.4, green: 0.7, blue: 1.0))
                        .frame(width: max(3, geo.size.width * fraction))
                }
            }
            .frame(height: 5)
        }
    }
}
