import AppKit

/// Geometry of the physical notch on the active screen.
/// On Macs without a notch a synthetic top-center notch is used, so the app
/// still works on external monitors and older Macs.
struct NotchMetrics {
    let screenFrame: NSRect
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let hasRealNotch: Bool

    static func current() -> NotchMetrics {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first!

        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top
        let hasNotch = topInset > 0

        let height: CGFloat = hasNotch ? topInset : 32

        var width: CGFloat = 200
        if hasNotch,
           let left = screen.auxiliaryTopLeftArea?.width,
           let right = screen.auxiliaryTopRightArea?.width,
           left > 0, right > 0 {
            width = frame.width - left - right
        }

        return NotchMetrics(
            screenFrame: frame,
            notchWidth: width,
            notchHeight: max(height, 30),
            hasRealNotch: hasNotch
        )
    }
}
