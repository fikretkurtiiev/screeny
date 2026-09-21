import CoreGraphics
import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

enum Exporter {
    /// Crops the frozen image at native resolution and draws annotations on top.
    /// `cropRect` is in image pixels with a top-left origin, like `CGImage.cropping(to:)`.
    static func flatten(image: CGImage, cropRect: CGRect, annotations: [Annotation]) -> CGImage? {
        guard let cropped = image.cropping(to: cropRect) else {
            Logger.export.error("Crop rect \(String(describing: cropRect), privacy: .public) is outside the image")
            return nil
        }
        let width = cropped.width
        let height = cropped.height
        guard let context = makeContext(width: width, height: height, preferredSpace: image.colorSpace) else {
            Logger.export.error("Could not create a \(width)×\(height) bitmap context")
            return nil
        }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Bitmap contexts are y-up; the renderer works y-down like the overlay.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        Renderer.draw(annotations, in: context)
        return context.makeImage()
    }

    static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Keeps the capture's color space (often Display P3) when an 8-bit context supports it, else falls back to sRGB.
    private static func makeContext(width: Int, height: Int, preferredSpace: CGColorSpace?) -> CGContext? {
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let candidates = [preferredSpace, CGColorSpace(name: CGColorSpace.sRGB)].compactMap { $0 }
        for space in candidates where space.model == .rgb {
            if let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: bitmapInfo
            ) {
                return context
            }
        }
        return nil
    }
}
