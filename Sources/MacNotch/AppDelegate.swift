import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let modules = AppModules()
    private var controller: NotchController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        controller = NotchController(modules: modules)
    }
}
