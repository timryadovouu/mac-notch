import SwiftUI

/// MM:SS from a number of seconds.
func formatTime(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    return String(format: "%02d:%02d", total / 60, total % 60)
}

func phaseColor(_ phase: PomodoroPhase) -> Color {
    switch phase {
    case .work: return Color(red: 1.0, green: 0.35, blue: 0.35)
    case .shortBreak: return Color(red: 0.3, green: 0.85, blue: 0.45)
    case .longBreak: return Color(red: 0.35, green: 0.6, blue: 1.0)
    }
}
