import AppKit

// Accessory-приложение: без иконки в Dock и без пункта в меню-баре.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
