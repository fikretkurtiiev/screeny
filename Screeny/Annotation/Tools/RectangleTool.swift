import CoreGraphics

struct RectangleTool: DragTool {
    private let start: CGPoint
    private var end: CGPoint
    private let style: ToolStyle

    init(start: CGPoint, style: ToolStyle) {
        self.start = start
        end = start
        self.style = style
    }

    mutating func drag(to point: CGPoint, constrained: Bool) {
        guard constrained else {
            end = point
            return
        }
        let dx = point.x - start.x
        let dy = point.y - start.y
        let side = max(abs(dx), abs(dy))
        end = CGPoint(x: start.x + (dx < 0 ? -side : side), y: start.y + (dy < 0 ? -side : side))
    }

    var annotation: Annotation? {
        let rect = CGRect(x: start.x, y: start.y, width: end.x - start.x, height: end.y - start.y).standardized
        guard rect.width >= 2, rect.height >= 2 else { return nil }
        return .rectangle(rect: rect, color: style.color, width: style.width)
    }
}
