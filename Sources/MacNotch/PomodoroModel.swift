import Foundation
import AppKit

enum PomodoroPhase {
    case work, shortBreak, longBreak

    var title: String {
        switch self {
        case .work: return "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long Break"
        }
    }
}

/// Classic Pomodoro: 4 focus intervals, a short break between them, and a long
/// break after the fourth.
final class PomodoroModel: ObservableObject {
    /// Selectable focus lengths, in minutes.
    static let presets = [5, 10, 15, 25, 30, 60]

    var workDuration: TimeInterval = 25 * 60
    let sessionsBeforeLongBreak = 4

    @Published private(set) var phase: PomodoroPhase = .work
    @Published private(set) var timeRemaining: TimeInterval
    @Published private(set) var isRunning = false
    @Published private(set) var completedWorkSessions = 0

    private let settings: Settings
    private var timer: Timer?

    /// The last session-end chime, held so it isn't freed mid-play.
    private var chime: NSSound?

    /// Fired when a phase completes naturally, with the new phase — used for the
    /// left-side "rest" / "focus" alert.
    var onPhaseChange: ((PomodoroPhase) -> Void)?

    init(settings: Settings) {
        self.settings = settings
        timeRemaining = workDuration
    }

    var currentPhaseDuration: TimeInterval {
        switch phase {
        case .work: return workDuration
        case .shortBreak: return TimeInterval(settings.shortBreakMinutes * 60)
        case .longBreak: return TimeInterval(settings.longBreakMinutes * 60)
        }
    }

    var workMinutes: Int { Int(workDuration / 60) }

    var progress: Double {
        let total = currentPhaseDuration
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - timeRemaining / total))
    }

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        timeRemaining = currentPhaseDuration
    }

    func skip() { advancePhase(playSound: false) }

    /// Apply a focus-length preset and restart the focus phase.
    func setWorkMinutes(_ minutes: Int) {
        workDuration = TimeInterval(minutes * 60)
        pause()
        phase = .work
        timeRemaining = workDuration
    }

    private func tick() {
        guard timeRemaining > 0 else { advancePhase(playSound: true); return }
        timeRemaining -= 1
    }

    private func advancePhase(playSound: Bool) {
        // Our NSSound plays directly, so Focus/Do Not Disturb does NOT mute it.
        // When the user opts out of sound during Focus, suppress it ourselves.
        let mutedByFocus = !settings.soundDuringDND && FocusMonitor.isActive
        if playSound && settings.pomodoroSound && !mutedByFocus {
            let s = NSSound(named: settings.pomodoroSoundName) ?? NSSound(named: "Funk")
            chime = s   // retain across the async play
            if let s { s.stop(); s.play() } else { NSSound.beep() }
        }
        switch phase {
        case .work:
            completedWorkSessions += 1
            phase = (completedWorkSessions % sessionsBeforeLongBreak == 0) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .work
        }
        timeRemaining = currentPhaseDuration
        if playSound { onPhaseChange?(phase) }
    }
}
