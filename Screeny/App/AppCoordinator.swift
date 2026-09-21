import AppKit
import OSLog

/// Owns the capture session: idle → capturing → selecting → annotating → (exporting) → idle.
@MainActor
final class AppCoordinator {
    enum State: Equatable {
        case idle
        case capturing
        case selecting
        case annotating
        case exporting
    }

    private(set) var state: State = .idle {
        didSet { Logger.app.debug("Session state: \(String(describing: self.state), privacy: .public)") }
    }

    private let preferences: Preferences
    private let capturer = ScreenCapturer()
    private var overlays: [OverlayWindow] = []
    private var previousApp: NSRunningApplication?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func startCapture() {
        // Only one session at a time; a hotkey press mid-session is ignored.
        guard state == .idle else { return }
        guard PermissionManager.hasScreenRecordingAccess else {
            PermissionManager.presentAccessAlert()
            return
        }
        state = .capturing
        previousApp = NSWorkspace.shared.frontmostApplication

        Task {
            do {
                // Freeze first: every display is captured before any overlay window exists.
                let displays = try await capturer.captureAllDisplays()
                presentOverlays(for: displays)
            } catch {
                Logger.capture.error("Capture failed: \(error.localizedDescription, privacy: .public)")
                state = .idle
                presentCaptureError(error)
            }
        }
    }

    private func presentOverlays(for displays: [CapturedDisplay]) {
        let images = Dictionary(displays.map { ($0.displayID, $0.image) }, uniquingKeysWith: { first, _ in first })
        overlays = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.displayID, let image = images[displayID] else {
                Logger.overlay.error("No capture for screen \(screen.localizedName, privacy: .public)")
                return nil
            }
            let window = OverlayWindow(screen: screen, image: image)
            window.overlayView.delegate = self
            return window
        }
        guard let fallback = overlays.first else {
            state = .idle
            return
        }

        NSApp.activate()
        overlays.forEach { $0.orderFrontRegardless() }
        let mouse = NSEvent.mouseLocation
        let keyWindow = overlays.first { $0.frame.contains(mouse) } ?? fallback
        keyWindow.makeKey()
        keyWindow.makeFirstResponder(keyWindow.overlayView)
        state = .selecting
    }

    private func dismissOverlays() {
        for window in overlays {
            window.overlayView.tearDown()
            window.orderOut(nil)
            window.close()
        }
        overlays = []
    }

    private func endSession() {
        dismissOverlays()
        state = .idle
        restorePreviousApp()
    }

    /// An accessory app doesn't hand focus back on its own when its windows close.
    private func restorePreviousApp() {
        defer { previousApp = nil }
        guard let app = previousApp, app != NSRunningApplication.current else { return }
        NSApp.yieldActivation(to: app)
        app.activate(from: NSRunningApplication.current, options: [])
    }

    private func presentCaptureError(_ error: Error) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Screeny couldn't capture the screen"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

extension AppCoordinator: OverlayViewDelegate {
    func overlayViewDidBeginSelection(_ view: OverlayView) {
        // Selection is limited to one display; starting one elsewhere clears the others.
        for window in overlays where window.overlayView !== view {
            window.overlayView.clearSelection()
        }
        state = .selecting
    }

    func overlayViewDidFinishSelection(_ view: OverlayView) {
        state = view.hasSelection ? .annotating : .selecting
    }

    func overlayViewDidRequestCopy(_ view: OverlayView) {
        guard let image = view.renderSelection(), ClipboardExporter.copy(image) else {
            Logger.export.error("Copy failed")
            NSSound.beep()
            return
        }
        endSession()
    }

    func overlayViewDidRequestSave(_ view: OverlayView) {
        guard let image = view.renderSelection(), let png = Exporter.pngData(from: image) else {
            Logger.export.error("Rendering for save failed")
            NSSound.beep()
            return
        }
        state = .exporting
        // A save panel can't appear above a .screenSaver-level overlay, so the overlay goes first.
        dismissOverlays()
        FileExporter.save(png, preferences: preferences)
        state = .idle
        restorePreviousApp()
    }

    func overlayViewDidRequestCancel(_: OverlayView) {
        endSession()
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
