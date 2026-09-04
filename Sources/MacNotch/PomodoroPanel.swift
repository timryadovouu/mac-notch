import SwiftUI

struct PomodoroPanel: View {
    @ObservedObject var model: PomodoroModel

    private var accent: Color { phaseColor(model.phase) }

    var body: some View {
        HStack(spacing: 20) {
            // Progress ring with the countdown.
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: model.progress)
                VStack(spacing: 1) {
                    Text(formatTime(model.timeRemaining))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(model.phase.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 118, height: 118)

            VStack(spacing: 10) {
                presets

                Button(action: model.toggle) {
                    HStack(spacing: 8) {
                        Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        Text(model.isRunning ? "Pause" : "Start")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(width: 156, height: 38)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    iconButton("arrow.counterclockwise", "Reset", action: model.reset)
                    iconButton("forward.fill", "Skip", action: model.skip)
                }
            }
        }
    }

    private var presets: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(PomodoroModel.presets.prefix(3), id: \.self) { presetChip($0) }
            }
            HStack(spacing: 5) {
                ForEach(PomodoroModel.presets.suffix(3), id: \.self) { presetChip($0) }
            }
        }
    }

    private func presetChip(_ minutes: Int) -> some View {
        let selected = model.phase == .work && model.workMinutes == minutes
        return Button { model.setWorkMinutes(minutes) } label: {
            Text("\(minutes)")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 48, height: 24)
                .background(selected ? accent.opacity(0.9) : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .frame(width: 74, height: 34)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
