import AppKit
import CoreGraphics

@MainActor
enum PermissionManager {
    static var hasScreenRecordingAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func presentAccessAlert() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Screeny needs Screen Recording access"
        alert.informativeText = """
        To capture your screen, turn on Screeny in System Settings › Privacy & Security › \
        Screen & System Audio Recording. You may need to quit and reopen Screeny afterwards.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // Adds Screeny to the Screen Recording list so the user only has to flip the switch.
        _ = CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
