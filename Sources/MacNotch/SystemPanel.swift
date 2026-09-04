import SwiftUI

struct SystemPanel: View {
    @ObservedObject var stats: SystemStats

    var body: some View {
        HStack(spacing: 26) {
            gauge(label: "CPU",
                  value: stats.cpu,
                  detail: "\(Int(stats.cpu * 100))%",
                  color: Color(red: 1.0, green: 0.45, blue: 0.4))
            gauge(label: "RAM",
                  value: stats.ramFraction,
                  detail: formatGB(stats.ramUsed),
                  color: Color(red: 0.4, green: 0.75, blue: 1.0))
            gauge(label: "Disk",
                  value: stats.diskFraction,
                  detail: "\(formatGB(stats.diskUsed))",
                  color: Color(red: 0.55, green: 0.85, blue: 0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func gauge(label: String, value: Double, detail: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, value)))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: value)
                Text("\(Int(value * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 84, height: 84)

            Text(label)
                .font(.system(size: 12, weight: .semibold))
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
