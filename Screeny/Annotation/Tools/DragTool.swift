import CoreGraphics

/// Color and width for new annotations. Width is in pixels.
struct ToolStyle: Equatable, Sendable {
    var color: RGBAColor
    var width: CGFloat
}

/// Input handling for a tool that creates an annotation by dragging. Points are selection-local pixels.
protocol DragTool: Sendable {
    /// `constrained` is true while Shift is held.
    mutating func drag(to point: CGPoint, constrained: Bool)
    /// The annotation so far, or nil while the gesture is too small to count.
    var annotation: Annotation? { get }
}

extension Tool {
    /// Nil for tools that aren't drag-based (text).
    func beginDrag(at point: CGPoint, style: ToolStyle) -> (any DragTool)? {
        switch self {
        case .pen:
            return FreehandTool(start: point, style: style, isMarker: false)
        case .marker:
            return FreehandTool(start: point, style: style, isMarker: true)
        case .line:
            return SegmentTool(start: point, style: style, hasArrowHead: false)
        case .arrow:
            return SegmentTool(start: point, style: style, hasArrowHead: true)
        case .rectangle:
            return RectangleTool(start: point, style: style)
        case .text:
            return nil
        }
    }
}
