import SwiftUI

/// Root view: the "brow" that lives over the physical notch and expands on
/// hover, Dynamic-Island style.
struct NotchRootView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var pomodoro: PomodoroModel
    @ObservedObject var media: MediaController
    @ObservedObject var claude: ClaudeSessionsManager
    @ObservedObject var settings: Settings
    let modules: AppModules
    let metrics: NotchMetrics

    @State private var playFlash = false   // brief play glyph when playback resumes

    // Expanded panel size.
    static let panelWidth: CGFloat = 560
    static let panelHeight: CGFloat = 272
    static let panelHeightTall: CGFloat = 430
    static func expandedHeight(_ tall: Bool) -> CGFloat { tall ? panelHeightTall : panelHeight }

    private let timerPillW: CGFloat = 70
    private let eqW: CGFloat = 40
    private let claudeW: CGFloat = 20   // small coral island; the pulsing dot sits centered
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
    /// A track is loaded but paused.
    private var paused: Bool { !state.expanded && media.source != .none && !media.isPlaying }

    private var rightExt: CGFloat { (!state.expanded && running) ? timerPillW : 0 }

    /// Coral "Claude is thinking" island, shown while ≥1 session is working.
    private var showClaude: Bool { !state.expanded && settings.trackClaude && claude.anyWorking }
    private var claudeExt: CGFloat { showClaude ? claudeW : 0 }

    /// Left extension shows either a transient alert or a music equalizer.
    private var leftExt: CGFloat {
        guard !state.expanded else { return 0 }
        if let alert = state.alert {
            return alert.text == nil ? 46 : 50 + CGFloat(alert.text?.count ?? 0) * 7.5
        }
        if playing || paused { return eqW }   // same width so ⏯ doesn't shift the notch
        return 0
    }

    private var islandW: CGFloat {
        state.expanded ? Self.panelWidth : notchW + leftExt + claudeExt + rightExt + bleed * 2
    }
    private var islandH: CGFloat { (state.expanded ? Self.expandedHeight(state.tall) : notchH) + Self.topOvershoot }
    private var radius: CGFloat { state.expanded ? 28 : min(13, notchH / 2) }
    // Shift the center so the middle (notch) portion stays over the camera.
    private var centerShift: CGFloat { state.expanded ? 0 : (claudeExt + rightExt - leftExt) / 2 }

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
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: paused)
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: showClaude)
                .animation(.spring(response: 0.34, dampingFraction: 0.84), value: state.tall)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Fill into the notch/menu-bar safe area so no thin gap shows at the top.
        .ignoresSafeArea(.all)
        .onChange(of: playing) { isPlaying in
            if isPlaying {
                playFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playFlash = false }
            }
        }
    }

    @ViewBuilder private var islandContent: some View {
        if state.expanded {
            ExpandedPanel(state: state, settings: modules.settings, system: modules.system,
                          modules: modules, notchWidth: notchW,
                          topInset: notchH + Self.topOvershoot)
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
                    if playFlash {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.980, green: 0.514, blue: 0.302))
                    } else {
                        EqualizerBars(color: Color(red: 0.35, green: 0.85, blue: 0.45))
                            .transition(.opacity)
                    }
                } else if paused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.980, green: 0.514, blue: 0.302))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: leftExt)

            // Center — camera area, drawn empty.
            Color.clear.frame(width: notchW)

            // Claude island (coral) — inner to the timer, shown while a session thinks.
            ZStack {
                if showClaude {
                    ClaudeBlob()
                        .frame(width: 11, height: 11)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: claudeExt)

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
        // Two sines with an irrational frequency ratio → long, organic, non-cyclic.
        let p = Double(i)
        let v = 0.5 + 0.30 * sin(t * 5.3 + p * 2.1) + 0.20 * sin(t * 9.7 + p * 4.3)
        return 4 + min(1, max(0, v)) * 12
    }
}

/// Small pulsing coral "blob" shown while a Claude session is thinking.
struct ClaudeBlob: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let p = 0.5 + 0.5 * sin(t * 3.0)   // 0...1
            Circle()
                .fill(Color(red: 0.980, green: 0.514, blue: 0.302))
                .scaleEffect(0.7 + 0.3 * p)
                .opacity(0.6 + 0.4 * p)
        }
    }
}
