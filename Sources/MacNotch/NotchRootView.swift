import SwiftUI

/// Root view: the "brow" that lives over the physical notch and expands on
/// hover, Dynamic-Island style.
struct NotchRootView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var pomodoro: PomodoroModel
    @ObservedObject var media: MediaController
    let modules: AppModules
    let metrics: NotchMetrics

    // Expanded panel size.
    static let panelWidth: CGFloat = 560
    static let panelHeight: CGFloat = 272

    private let timerPillW: CGFloat = 70
    private let eqW: CGFloat = 40
    // Extra black bled onto the menu bar on each side, to hide the 1px seam
    // between the pure-black notch and the tinted menu bar.
    private let bleed: CGFloat = 2
    // The window is shifted up by this much (see NotchController); the island is
    // grown upward by the same amount so black covers the very top rows with no
    // thin gap, while everything below stays put.
    static let topOvershoot: CGFloat = 3

    private var notchW: CGFloat { metrics.notchWidth }
    private var notchH: CGFloat { metrics.notchHeight }
    private var running: Bool { pomodoro.isRunning }
    private var playing: Bool { media.isPlaying }

    private var rightExt: CGFloat { (!state.expanded && running) ? timerPillW : 0 }

    /// Left extension shows either a transient alert or a music equalizer.
    private var leftExt: CGFloat {
        guard !state.expanded else { return 0 }
        if let alert = state.alert {
            return alert.text == nil ? 46 : 50 + CGFloat(alert.text?.count ?? 0) * 7.5
        }
        if playing { return eqW }
        return 0
    }

    private var islandW: CGFloat {
        state.expanded ? Self.panelWidth : notchW + leftExt + rightExt + bleed * 2
    }
    private var islandH: CGFloat { (state.expanded ? Self.panelHeight : notchH) + Self.topOvershoot }
    private var radius: CGFloat { state.expanded ? 28 : min(13, notchH / 2) }
    // Shift the center so the middle (notch) portion stays over the camera.
    private var centerShift: CGFloat { state.expanded ? 0 : (rightExt - leftExt) / 2 }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            islandContent
                .frame(width: islandW, height: islandH, alignment: .top)
                .background(Color.black)
                .clipShape(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(bottomLeading: radius, bottomTrailing: radius),
                        style: .continuous
                    )
                )
                .overlay(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(bottomLeading: radius, bottomTrailing: radius),
                        style: .continuous
                    )
                    .strokeBorder(Color.white.opacity(state.expanded ? 0.09 : 0), lineWidth: 1)
                )
                .shadow(color: .black.opacity(state.expanded ? 0.55 : 0), radius: 16, y: 8)
                .offset(x: centerShift)
                .animation(.spring(response: 0.26, dampingFraction: 0.86), value: state.expanded)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: state.alert)
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: running)
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: playing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Fill into the notch/menu-bar safe area so no thin gap shows at the top.
        .ignoresSafeArea(.all)
    }

    @ViewBuilder private var islandContent: some View {
        if state.expanded {
            ExpandedPanel(state: state, modules: modules, topInset: notchH + Self.topOvershoot)
                .transition(.opacity)
        } else {
            collapsed
        }
    }

    private var collapsed: some View {
        HStack(spacing: 0) {
            // Left extension — alert, or music equalizer while playing.
            ZStack {
                if let alert = state.alert {
                    HStack(spacing: 5) {
                        Image(systemName: alert.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(alert.color)
                        if let text = alert.text {
                            Text(text)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .fixedSize()
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                } else if playing {
                    EqualizerBars(color: Color(red: 0.35, green: 0.85, blue: 0.45))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: leftExt)

            // Center — camera area, drawn empty.
            Color.clear.frame(width: notchW)

            // Right extension — running countdown.
            ZStack {
                if running {
                    Text(formatTime(pomodoro.timeRemaining))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(phaseColor(pomodoro.phase))
                        .transition(.opacity)
                }
            }
            .frame(width: rightExt)
        }
        .frame(height: notchH)
        .padding(.top, Self.topOvershoot)   // keep content below the extended black top
    }
}

/// Three pulsing bars, like the Dynamic Island "now playing" indicator.
struct EqualizerBars: View {
    var color: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: height(t, i))
                }
            }
            .frame(height: 16)
        }
    }

    private func height(_ t: Double, _ i: Int) -> CGFloat {
        let v = (sin(t * 6.0 + Double(i) * 1.3) + 1) / 2   // 0...1
        return 4 + v * 12
    }
}
