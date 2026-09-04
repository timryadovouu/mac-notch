import SwiftUI

struct ScreenTimePanel: View {
    @ObservedObject var usage: AppUsageTracker

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                stat(title: "Total", value: formatDuration(usage.totalSeconds))
                Spacer()
                stat(title: "Switches", value: "\(usage.switchCount)")
            }

            if usage.ranked.isEmpty {
                Spacer()
                Text("Tracking starts now").font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 7) {
                        ForEach(usage.ranked.prefix(8)) { app in
                            row(app)
                        }
                    }
                }
            }
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).monospacedDigit()
        }
    }

    private func row(_ app: AppUsage) -> some View {
        let fraction = usage.totalSeconds > 0 ? Double(app.seconds) / Double(usage.totalSeconds) : 0
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
