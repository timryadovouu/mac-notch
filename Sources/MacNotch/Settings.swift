import Foundation
import Combine

/// Persisted app settings (UserDefaults-backed).
final class Settings: ObservableObject {
    /// Folder where the clipboard buffer is stored.
    @Published var bufferRootPath: String {
        didSet { d.set(bufferRootPath, forKey: "bufferRootPath") }
    }
    /// Delete buffer day-folders older than this many days.
    @Published var bufferRetentionDays: Int {
        didSet { d.set(bufferRetentionDays, forKey: "bufferRetentionDays") }
    }
    /// If on, each day's buffer folder is deleted once that day ends (keep only today).
    @Published var clearBufferAtEndOfDay: Bool {
        didSet { d.set(clearBufferAtEndOfDay, forKey: "clearBufferAtEndOfDay") }
    }
    /// After this many minutes without opening the notch, reset to the default tab.
    @Published var recallMinutes: Int {
        didSet { d.set(recallMinutes, forKey: "recallMinutes") }
    }
    /// Which tab opens by default.
    @Published var defaultModuleRaw: String {
        didSet { d.set(defaultModuleRaw, forKey: "defaultModuleRaw") }
    }

    private let d = UserDefaults.standard

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        bufferRootPath = d.string(forKey: "bufferRootPath")
            ?? docs.appendingPathComponent("localBuffer").path
        bufferRetentionDays = d.object(forKey: "bufferRetentionDays") as? Int ?? 7
        clearBufferAtEndOfDay = d.object(forKey: "clearBufferAtEndOfDay") as? Bool ?? false
        recallMinutes = d.object(forKey: "recallMinutes") as? Int ?? 30
        defaultModuleRaw = d.string(forKey: "defaultModuleRaw") ?? Module.tasks.rawValue
    }

    var bufferRoot: URL { URL(fileURLWithPath: bufferRootPath) }
    var defaultModule: Module { Module(rawValue: defaultModuleRaw) ?? .tasks }
}
