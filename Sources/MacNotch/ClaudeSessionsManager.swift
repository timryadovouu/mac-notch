import Foundation

/// Watches the event log that Claude Code's hooks append to, and exposes whether
/// any session is currently "thinking" (working). No UI tab — just drives the
/// small coral island in the collapsed notch.
final class ClaudeSessionsManager: ObservableObject {
    @Published private(set) var anyWorking = false

    /// When the exhausted usage window frees up, if a limit is currently hit.
    /// nil when no window is at/over the block threshold (Claude is available).
    /// Fed by ratelimit.json, which our statusLine command writes.
    @Published private(set) var limitResetAt: Date?

    /// A session is dropped from "working" if it hasn't produced an event in this
    /// long (guards against a session that never emits Stop, e.g. after a crash).
    private let workingTimeout: TimeInterval = 10 * 60

    /// A window counts as "hit" (Claude blocked) at or above this percentage.
    private let limitBlockThreshold = 99.0

    private var status: [String: (working: Bool, at: Date)] = [:]
    private var offset: UInt64 = 0
    private var timer: Timer?

    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var dir: URL { home.appendingPathComponent(".claude/mac-notch") }
    private var eventsFile: URL { dir.appendingPathComponent("events.jsonl") }
    private var rateLimitFile: URL { dir.appendingPathComponent("ratelimit.json") }
    private var settingsFile: URL { home.appendingPathComponent(".claude/settings.json") }

    init() {
        // Start from the end of the log — events written before launch must not
        // count as "thinking now" (otherwise the island hangs after relaunch).
        if let size = (try? FileManager.default.attributesOfItem(atPath: eventsFile.path))?[.size] as? NSNumber {
            offset = size.uint64Value
        }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Reading events

    private func poll() {
        if let handle = try? FileHandle(forReadingFrom: eventsFile) {
            defer { try? handle.close() }
            let end = (try? handle.seekToEnd()) ?? 0
            if end < offset { offset = 0; status = [:] }   // rotated/truncated
            if end > offset {
                try? handle.seek(toOffset: offset)
                let data = handle.readDataToEndOfFile()
                offset = end
                for line in (String(data: data, encoding: .utf8) ?? "").split(separator: "\n") {
                    process(String(line))
                }
            }
        }
        recompute()
        readRateLimit()
    }

    /// Read the reset times captured by our statusLine command. The binding
    /// reset is the latest `resets_at` among windows that are currently hit; if
    /// none are hit, Claude is available and this is nil.
    private func readRateLimit() {
        guard let data = try? Data(contentsOf: rateLimitFile),
              let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            if limitResetAt != nil { limitResetAt = nil }
            return
        }
        var candidates: [Date] = []
        for (usedKey, resetKey) in [("five_hour_used", "five_hour_resets_at"),
                                    ("seven_day_used", "seven_day_resets_at")] {
            if let used = o[usedKey] as? Double, used >= limitBlockThreshold,
               let epoch = o[resetKey] as? Double {
                candidates.append(Date(timeIntervalSince1970: epoch))
            }
        }
        let reset = candidates.max()
        if reset != limitResetAt { limitResetAt = reset }
    }

    private func process(_ line: String) {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = obj["session_id"] as? String,
              let event = obj["hook_event_name"] as? String else { return }
        // "Thinking" is strictly between the user's prompt and Stop; any other
        // event (Stop, Notification, SessionStart, SubagentStop) clears it.
        let working = (event == "UserPromptSubmit")
        if event == "SessionEnd" { status[id] = nil } else { status[id] = (working, Date()) }
    }

    private func recompute() {
        let now = Date()
        let working = status.values.contains { $0.working && now.timeIntervalSince($0.at) < workingTimeout }
        if working != anyWorking { anyWorking = working }
    }

    // MARK: - Setup

    /// Merge our hooks into ~/.claude/settings.json (backed up first).
    @discardableResult
    func installHooks() -> Bool {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsFile) {
            try? data.write(to: settingsFile.appendingPathExtension("bak"))
            root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        }

        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let cmd = "mkdir -p \"$HOME/.claude/mac-notch\" && { cat; echo; } >> \"$HOME/.claude/mac-notch/events.jsonl\""
        let group: [String: Any] = ["hooks": [["type": "command", "command": cmd]]]

        for event in ["UserPromptSubmit", "Stop", "Notification", "SessionStart", "SessionEnd", "SubagentStop"] {
            var arr = hooks[event] as? [[String: Any]] ?? []
            let already = arr.contains { g in
                (g["hooks"] as? [[String: Any]])?.contains { ($0["command"] as? String) == cmd } ?? false
            }
            if !already { arr.append(group) }
            hooks[event] = arr
        }
        root["hooks"] = hooks

        // statusLine: the only source of the usage-limit reset times. Point it at
        // our own executable's hidden `statusline` subcommand.
        let exe = Bundle.main.executableURL?.path ?? CommandLine.arguments.first ?? "mac-notch"
        root["statusLine"] = ["type": "command", "command": "\"\(exe)\" statusline"]

        guard let out = try? JSONSerialization.data(withJSONObject: root,
                                                    options: [.prettyPrinted, .sortedKeys]) else { return false }
        do { try out.write(to: settingsFile); return true } catch { return false }
    }
}
