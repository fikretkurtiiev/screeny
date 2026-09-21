import AppKit
import CoreGraphics

@MainActor
enum ClipboardExporter {
    @discardableResult
    static func copy(_ image: CGImage) -> Bool {
        guard let png = Exporter.pngData(from: image) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        pasteboard.setData(png, forType: .png)
        // Some older apps only read TIFF from the pasteboard.
        if let tiff = NSBitmapImageRep(cgImage: image).tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
        return true
    }
}
