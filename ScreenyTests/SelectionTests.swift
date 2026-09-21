import CoreGraphics
@testable import Screeny
import Testing

struct SelectionSpaceTests {
    private let space = SelectionSpace(selection: CGRect(x: 100, y: 50, width: 200, height: 100), scale: 2)

    @Test func convertsViewPointsToSelectionPixels() {
        #expect(space.pixelPoint(fromViewPoint: CGPoint(x: 110, y: 60)) == CGPoint(x: 20, y: 20))
    }

    @Test func roundTrips() {
        let point = CGPoint(x: 123.5, y: 77)
        #expect(space.viewPoint(fromPixelPoint: space.pixelPoint(fromViewPoint: point)) == point)
    }

    @Test func imagePixelRectIsScaled() {
        #expect(space.imagePixelRect == CGRect(x: 200, y: 100, width: 400, height: 200))
        #expect(space.pixelSize == CGSize(width: 400, height: 200))
    }
}

struct SelectionControllerTests {
    private func makeController(scale: CGFloat = 1) -> SelectionController {
        SelectionController(bounds: CGRect(x: 0, y: 0, width: 200, height: 100), scale: scale)
    }

    private func created(from start: CGPoint, to end: CGPoint, scale: CGFloat = 1) -> SelectionController {
        var controller = makeController(scale: scale)
        controller.beginCreating(at: start)
        controller.update(to: end)
        controller.end()
        return controller
    }

    @Test func createsNormalizedRect() {
        let controller = created(from: CGPoint(x: 50, y: 40), to: CGPoint(x: 10, y: 10))
        #expect(controller.rect == CGRect(x: 10, y: 10, width: 40, height: 30))
    }

    @Test func clampsToBounds() {
        let controller = created(from: CGPoint(x: 150, y: 50), to: CGPoint(x: 400, y: 300))
        #expect(controller.rect == CGRect(x: 150, y: 50, width: 50, height: 50))
    }

    @Test func discardsTinySelection() {
        let controller = created(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 11, y: 30))
        #expect(controller.rect == nil)
    }

    @Test func snapsToPixelGrid() {
        let controller = created(from: CGPoint(x: 10.3, y: 10.2), to: CGPoint(x: 20.9, y: 20.6), scale: 2)
        #expect(controller.rect == CGRect(x: 10.5, y: 10, width: 10.5, height: 10.5))
    }

    @Test func moveStaysInsideBounds() {
        var controller = created(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 40))
        controller.beginMoving(at: CGPoint(x: 20, y: 20))
        controller.update(to: CGPoint(x: 500, y: -500))
        controller.end()
        #expect(controller.rect == CGRect(x: 160, y: 0, width: 40, height: 30))
    }

    @Test func resizeFlipsPastOppositeEdge() {
        var controller = created(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 40))
        controller.beginResizing(.left, at: CGPoint(x: 10, y: 25))
        controller.update(to: CGPoint(x: 70, y: 25))
        controller.end()
        #expect(controller.rect == CGRect(x: 50, y: 10, width: 20, height: 30))
    }

    @Test func findsHandles() {
        let controller = created(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 40))
        #expect(controller.handle(at: CGPoint(x: 12, y: 8)) == .topLeft)
        #expect(controller.handle(at: CGPoint(x: 30, y: 41)) == .bottom)
        #expect(controller.handle(at: CGPoint(x: 30, y: 25)) == nil)
    }
}
