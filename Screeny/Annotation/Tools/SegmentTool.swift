import CoreGraphics

/// Straight line and arrow.
struct SegmentTool: DragTool {
    private let start: CGPoint
    private var end: CGPoint
    private let style: ToolStyle
    private let hasArrowHead: Bool

    init(start: CGPoint, style: ToolStyle, hasArrowHead: Bool) {
        self.start = start
        end = start
        self.style = style
        self.hasArrowHead = hasArrowHead
    }

    mutating func drag(to point: CGPoint, constrained: Bool) {
        end = constrained ? Self.snappedEnd(from: start, to: point) : point
    }

    var annotation: Annotation? {
        guard hypot(end.x - start.x, end.y - start.y) >= 2 else { return nil }
        if hasArrowHead {
            return .arrow(from: start, to: end, color: style.color, width: style.width)
        }
        return .line(from: start, to: end, color: style.color, width: style.width)
    }

    /// Snaps the angle to the nearest 45° while keeping the length.
    static func snappedEnd(from start: CGPoint, to point: CGPoint) -> CGPoint {
        let dx = point.x - start.x
        let dy = point.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return point }
        let step = CGFloat.pi / 4
        let angle = (atan2(dy, dx) / step).rounded() * step
        return CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
    }
}
