import CoreGraphics

/// Pen and marker.
struct FreehandTool: DragTool {
    static let markerWidthMultiplier: CGFloat = 4

    private var points: [CGPoint]
    private let style: ToolStyle
    private let isMarker: Bool

    init(start: CGPoint, style: ToolStyle, isMarker: Bool) {
        points = [start]
        self.style = style
        self.isMarker = isMarker
    }

    mutating func drag(to point: CGPoint, constrained _: Bool) {
        // Skip sub-pixel jitter so long strokes don't balloon the point array.
        if let last = points.last, hypot(point.x - last.x, point.y - last.y) < 1 { return }
        points.append(point)
    }

    var annotation: Annotation? {
        if isMarker {
            return .marker(points: points, color: style.color, width: style.width * Self.markerWidthMultiplier)
        }
        return .stroke(points: points, color: style.color, width: style.width)
    }
}
