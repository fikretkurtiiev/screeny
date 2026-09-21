import CoreGraphics
@testable import Screeny
import Testing

struct ToolTests {
    private let style = ToolStyle(color: .red, width: 4)

    @Test func segmentSnapsToFortyFiveDegrees() {
        let end = SegmentTool.snappedEnd(from: .zero, to: CGPoint(x: 10, y: 1))
        #expect(abs(end.y) < 0.0001)
        #expect(abs(end.x - hypot(10, 1)) < 0.0001)
    }

    @Test func tinyDragsProduceNothing() {
        for tool in [Tool.line, .arrow, .rectangle] {
            var drag = tool.beginDrag(at: CGPoint(x: 5, y: 5), style: style)
            drag?.drag(to: CGPoint(x: 5.5, y: 5.5), constrained: false)
            #expect(drag?.annotation == nil, "\(tool)")
        }
    }

    @Test func constrainedRectangleIsSquare() {
        var drag = Tool.rectangle.beginDrag(at: CGPoint(x: 10, y: 10), style: style)
        drag?.drag(to: CGPoint(x: 0, y: 40), constrained: true)
        #expect(drag?.annotation == .rectangle(rect: CGRect(x: -20, y: 10, width: 30, height: 30), color: .red, width: 4))
    }

    @Test func markerIsWiderThanPen() {
        let drag = Tool.marker.beginDrag(at: .zero, style: style)
        #expect(drag?.annotation == .marker(points: [.zero], color: .red, width: 4 * FreehandTool.markerWidthMultiplier))
    }

    @Test func textIsNotADragTool() {
        #expect(Tool.text.beginDrag(at: .zero, style: style) == nil)
    }

    @Test func blankTextIsDiscarded() {
        #expect(TextTool.annotation(string: " \n", origin: .zero, fontSize: 20, color: .red) == nil)
    }
}

struct ToolbarLayoutTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = CGSize(width: 300, height: 40)

    @Test func prefersBelowRightAligned() {
        let frame = ToolbarLayout.frame(for: size, selection: CGRect(x: 100, y: 100, width: 400, height: 200), bounds: bounds)
        #expect(frame == CGRect(x: 200, y: 308, width: 300, height: 40))
    }

    @Test func goesAboveWhenNoRoomBelow() {
        let frame = ToolbarLayout.frame(for: size, selection: CGRect(x: 100, y: 500, width: 400, height: 280), bounds: bounds)
        let expectedY: CGFloat = 500 - ToolbarLayout.gap - 40
        #expect(frame.minY == expectedY)
    }

    @Test func goesInsideForFullScreenSelection() {
        let frame = ToolbarLayout.frame(for: size, selection: bounds, bounds: bounds)
        #expect(bounds.contains(frame))
    }

    @Test func staysOnScreenHorizontally() {
        let frame = ToolbarLayout.frame(for: size, selection: CGRect(x: 0, y: 100, width: 50, height: 50), bounds: bounds)
        #expect(frame.minX == 8)
    }
}
