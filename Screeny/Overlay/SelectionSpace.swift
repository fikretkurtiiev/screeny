import CoreGraphics

/// The single mapping between overlay view points and selection-local pixels.
///
/// `OverlayView` is flipped, so view points already have a top-left origin like `CGImage`;
/// the only differences left are the selection offset and the backing scale factor.
struct SelectionSpace: Equatable, Sendable {
    /// Selection rect in overlay view points.
    var selection: CGRect
    var scale: CGFloat

    func pixelPoint(fromViewPoint point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - selection.minX) * scale, y: (point.y - selection.minY) * scale)
    }

    func viewPoint(fromPixelPoint point: CGPoint) -> CGPoint {
        CGPoint(x: point.x / scale + selection.minX, y: point.y / scale + selection.minY)
    }

    /// The selection in the frozen display image's pixel space, rounded to whole pixels.
    var imagePixelRect: CGRect {
        CGRect(
            x: (selection.minX * scale).rounded(),
            y: (selection.minY * scale).rounded(),
            width: (selection.width * scale).rounded(),
            height: (selection.height * scale).rounded()
        )
    }

    var pixelSize: CGSize { imagePixelRect.size }
}
