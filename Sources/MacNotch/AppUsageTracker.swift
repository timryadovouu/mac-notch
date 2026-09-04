import AppKit

struct AppUsage: Identifiable, Hashable {
    let id: String       // app name
    var name: String { id }
    let seconds: Int
    let iconPath: String?    // app bundle path, for its icon
}

/// Screen-time tracking done locally: every second we credit the frontmost app.
/// Everything stays on this Mac, persisted per day. Resets at midnight.
final class AppUsageTracker: ObservableObject {
    @Published private(set) var ranked: [AppUsage] = []
    @Published private(set) var totalSeconds = 0
    @Published private(set) var switchCount = 0

    private var perApp: [String: Int] = [:]
    private var paths: [String: String] = [:]   // app name -> bundle path
    private var lastApp: String?
    private var day = AppUsageTracker.dayString()
    private var tick = 0
    private var timer: Timer?

    private let selfName = NSRunningApplication.current.localizedName ?? "MacNotch"

    init() {
        load()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func step() {
        // Roll over at midnight.
        let today = Self.dayString()
        if today != day {
            save()
            perApp = [:]; paths = [:]; totalSeconds = 0; switchCount = 0; lastApp = nil
            day = today
        }

        guard let front = NSWorkspace.shared.frontmostApplication,
              let app = front.localizedName,
              app != selfName else { rebuild(); return }

        if app != lastApp {
            if lastApp != nil { switchCount += 1 }
            lastApp = app
        }
        perApp[app, default: 0] += 1
        if let path = front.bundleURL?.path { paths[app] = path }
        totalSeconds += 1

        tick += 1
        if tick % 15 == 0 { save() }
        rebuild()
    }

    private func rebuild() {
        ranked = perApp
            .map { AppUsage(id: $0.key, seconds: $0.value, iconPath: paths[$0.key]) }
            .sorted { $0.seconds > $1.seconds }
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var day: String
        var total: Int
        var switches: Int
        var apps: [String: Int]
        var paths: [String: String]?
    }

    private var fileURL: URL {
        AppModules.supportDirectory.appendingPathComponent("screentime.json")
    }

    private func save() {
        let snap = Snapshot(day: day, total: totalSeconds, switches: switchCount,
                            apps: perApp, paths: paths)
        if let data = try? JSONEncoder().encode(snap) { try? data.write(to: fileURL) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data),
              snap.day == day else { return }
        perApp = snap.apps
        paths = snap.paths ?? [:]
        totalSeconds = snap.total
        switchCount = snap.switches
        rebuild()
    }

    private static func dayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
}

/// "1h 23m" / "12m" / "45s"
func formatDuration(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    if h > 0 { return "\(h)h \(m)m" }
    if m > 0 { return "\(m)m" }
    return "\(s)s"
}
