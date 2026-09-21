import CoreGraphics
@testable import Screeny
import Testing

struct ExporterTests {
    /// 100×80: top half green, bottom half blue (in image orientation).
    private func makeTwoToneImage() -> CGImage {
        let bitmap = TestBitmap(width: 100, height: 80)
        bitmap.context.setFillColor(RGBAColor.blue.cgColor)
        bitmap.context.fill(CGRect(x: 0, y: 0, width: 100, height: 40))
        // Bitmap contexts are y-up, so the upper half of user space is the top of the image.
        bitmap.context.setFillColor(RGBAColor.green.cgColor)
        bitmap.context.fill(CGRect(x: 0, y: 40, width: 100, height: 40))
        return bitmap.context.makeImage()!
    }

    @Test func cropsAtNativeResolution() throws {
        let output = try #require(Exporter.flatten(image: makeTwoToneImage(), cropRect: CGRect(x: 10, y: 20, width: 30, height: 40), annotations: []))
        #expect(output.width == 30)
        #expect(output.height == 40)
    }

    @Test func cropRectUsesTopLeftOrigin() throws {
        let output = try #require(Exporter.flatten(image: makeTwoToneImage(), cropRect: CGRect(x: 0, y: 0, width: 20, height: 10), annotations: []))
        let pixel = TestBitmap(image: output).pixel(x: 5, y: 5)
        #expect(pixel.green > 150 && pixel.blue < 150, "the top of the image is green")
    }

    @Test func drawsAnnotationsOverTheCrop() throws {
        let annotation = Annotation.rectangle(rect: CGRect(x: 0, y: 0, width: 20, height: 10), color: .red, width: 4)
        let output = try #require(Exporter.flatten(image: makeTwoToneImage(), cropRect: CGRect(x: 0, y: 0, width: 20, height: 10), annotations: [annotation]))
        let bitmap = TestBitmap(image: output)
        #expect(bitmap.pixel(x: 0, y: 0).red > 200)
        #expect(bitmap.pixel(x: 10, y: 5).red < 100)
    }

    @Test func producesPNGData() throws {
        let data = try #require(Exporter.pngData(from: makeTwoToneImage()))
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }
}
