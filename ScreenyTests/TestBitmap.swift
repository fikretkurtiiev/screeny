import CoreGraphics

/// An RGBA sRGB bitmap with top-left pixel addressing, for pixel assertions.
struct TestBitmap {
    struct Pixel: Equatable {
        let red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8
    }

    let context: CGContext
    let width: Int
    let height: Int

    /// A transparent canvas already flipped to y-down, as the Renderer expects.
    static func flippedCanvas(width: Int, height: Int) -> TestBitmap {
        let bitmap = TestBitmap(width: width, height: height)
        bitmap.context.translateBy(x: 0, y: CGFloat(height))
        bitmap.context.scaleBy(x: 1, y: -1)
        return bitmap
    }

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    init(image: CGImage) {
        self.init(width: image.width, height: image.height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    /// Row 0 of a bitmap context's memory is the top row of the image.
    func pixel(x: Int, y: Int) -> Pixel {
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        let offset = y * context.bytesPerRow + x * 4
        return Pixel(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2], alpha: bytes[offset + 3])
    }

    func hasInk(inRows rows: Range<Int>, columns: Range<Int>) -> Bool {
        rows.contains { y in columns.contains { x in pixel(x: x, y: y).alpha > 0 } }
    }
}
