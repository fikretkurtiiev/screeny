import AppKit

/// A plain AppKit entry point: a menu bar app needs no SwiftUI scenes, and Settings is an ordinary window.
@main
enum ScreenyApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        // NSApplication holds its delegate weakly.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
