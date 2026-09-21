import CoreGraphics
import OSLog
import ScreenCaptureKit

struct CapturedDisplay: @unchecked Sendable {
    // @unchecked: CGImage is immutable once created, so sharing it across actors is safe.
    let displayID: CGDirectDisplayID
    let image: CGImage
}

struct ScreenCapturer: Sendable {
    /// Captures a full-resolution still of every display, without the cursor.
    func captureAllDisplays() async throws -> [CapturedDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        var captures: [CapturedDisplay] = []
        for display in content.displays {
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            // pointPixelScale is macOS 14+; it matches the screen's backingScaleFactor.
            let scale = CGFloat(filter.pointPixelScale)
            configuration.width = Int((filter.contentRect.width * scale).rounded())
            configuration.height = Int((filter.contentRect.height * scale).rounded())
            configuration.showsCursor = false
            configuration.captureResolution = .best
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            captures.append(CapturedDisplay(displayID: display.displayID, image: image))
        }
        Logger.capture.debug("Captured \(captures.count) display(s)")
        return captures
    }
}
