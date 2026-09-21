import CoreGraphics
@testable import Screeny
import Testing

struct RendererTests {
    @Test func rectangleIsDrawnTopLeftOrigin() {
        let bitmap = TestBitmap.flippedCanvas(width: 40, height: 40)
        Renderer.draw([.rectangle(rect: CGRect(x: 10, y: 5, width: 20, height: 10), color: .black, width: 2)], in: bitmap.context)

        #expect(bitmap.pixel(x: 20, y: 5).alpha == 255, "top edge is near the top of the image")
        #expect(bitmap.pixel(x: 20, y: 35).alpha == 0, "nothing where a y-up renderer would have drawn")
        #expect(bitmap.pixel(x: 20, y: 10).alpha == 0, "interior stays empty")
    }

    @Test func markerIsTranslucent() {
        let bitmap = TestBitmap.flippedCanvas(width: 40, height: 40)
        let points = [CGPoint(x: 5, y: 20), CGPoint(x: 35, y: 20)]
        Renderer.draw([.marker(points: points, color: .yellow, width: 10)], in: bitmap.context)

        let alpha = Double(bitmap.pixel(x: 20, y: 20).alpha) / 255
        #expect(abs(alpha - Renderer.markerOpacity) < 0.02)
    }

    @Test func singlePointStrokeDrawsADot() {
        let bitmap = TestBitmap.flippedCanvas(width: 20, height: 20)
        Renderer.draw([.stroke(points: [CGPoint(x: 10, y: 10)], color: .black, width: 6)], in: bitmap.context)
        #expect(bitmap.pixel(x: 10, y: 10).alpha == 255)
    }

    @Test func arrowHeadCoversTheTip() {
        let bitmap = TestBitmap.flippedCanvas(width: 60, height: 20)
        Renderer.draw([.arrow(from: CGPoint(x: 5, y: 10), to: CGPoint(x: 55, y: 10), color: .black, width: 2)], in: bitmap.context)

        // The head is wider than the shaft: 2.5px off-axis is ink inside the head but not mid-shaft.
        #expect(bitmap.pixel(x: 48, y: 12).alpha > 0)
        #expect(bitmap.pixel(x: 25, y: 12).alpha == 0)
    }

    @Test func textStartsBelowItsOrigin() {
        let bitmap = TestBitmap.flippedCanvas(width: 120, height: 60)
        Renderer.draw([.text(string: "Hello", origin: CGPoint(x: 10, y: 20), fontSize: 20, color: .black)], in: bitmap.context)

        #expect(bitmap.hasInk(inRows: 20 ..< 45, columns: 10 ..< 120))
        #expect(!bitmap.hasInk(inRows: 0 ..< 19, columns: 0 ..< 120))
    }
}
