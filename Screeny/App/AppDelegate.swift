import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private lazy var coordinator = AppCoordinator(preferences: preferences)
    private lazy var settingsWindow = SettingsWindowController(preferences: preferences)
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_: Notification) {
        // Unit tests are hosted in the app; keep them free of the status item and global hotkey.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        setUpStatusItem()
        KeyboardShortcuts.onKeyUp(for: .captureRegion) { [weak self] in
            self?.coordinator.startCapture()
        }
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Screeny")

        let menu = NSMenu()
        let capture = NSMenuItem(title: "Capture Region", action: #selector(captureFromMenu), keyEquivalent: "")
        capture.target = self
        capture.setShortcut(for: .captureRegion)
        menu.addItem(capture)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Screeny", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func captureFromMenu() {
        // Give the menu time to fade out so it isn't frozen into the capture.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            self?.coordinator.startCapture()
        }
    }

    @objc private func showSettings() {
        settingsWindow.show()
    }
}
