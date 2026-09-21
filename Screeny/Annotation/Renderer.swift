import CoreGraphics
import CoreText
import Foundation

/// Draws annotations in selection-local pixel coordinates.
///
/// The context must already be y-down (top-left origin): the overlay view is flipped and the exporter flips its bitmap.
/// Both the on-screen canvas and the exporter go through here so the export matches what the user saw.
enum Renderer {
    static let markerOpacity: CGFloat = 0.4

    static func draw(_ annotations: [Annotation], in context: CGContext) {
        for annotation in annotations {
            draw(annotation, in: context)
        }
    }

    static func draw(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation {
        case let .stroke(points, color, width):
            drawFreehand(points, color: color, width: width, in: context)
        case let .marker(points, color, width):
            // One path stroked once, so self-overlapping parts don't stack opacity.
            drawFreehand(points, color: color.withAlpha(markerOpacity), width: width, in: context)
        case let .line(from, to, color, width):
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(width)
            context.strokeLineSegments(between: [from, to])
        case let .arrow(from, to, color, width):
            drawArrow(from: from, to: to, color: color, width: width, in: context)
        case let .rectangle(rect, color, width):
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(width)
            context.setLineJoin(.miter)
            context.stroke(rect.standardized)
        case let .text(string, origin, fontSize, color):
            drawText(string, origin: origin, fontSize: fontSize, color: color, in: context)
        }
    }

    private static func drawFreehand(_ points: [CGPoint], color: RGBAColor, width: CGFloat, in context: CGContext) {
        guard let first = points.first else { return }
        if points.count == 1 {
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(x: first.x - width / 2, y: first.y - width / 2, width: width, height: width))
            return
        }
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.addPath(smoothedPath(through: points))
        context.strokePath()
    }

    /// Quadratic curves through segment midpoints smooth out mouse jitter without overshooting.
    private static func smoothedPath(through points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first, let last = points.last else { return path }
        path.move(to: first)
        if points.count > 2 {
            for index in 1 ..< points.count - 1 {
                let current = points[index]
                let next = points[index + 1]
                path.addQuadCurve(to: CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2), control: current)
            }
        }
        path.addLine(to: last)
        return path
    }

    private static func drawArrow(from: CGPoint, to: CGPoint, color: RGBAColor, width: CGFloat, in context: CGContext) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = hypot(dx, dy)
        guard length > 0 else { return }

        let headLength = min(max(width * 4, 12), length)
        let headHalfWidth = headLength * 0.5
        let ux = dx / length
        let uy = dy / length
        let base = CGPoint(x: to.x - ux * headLength, y: to.y - uy * headLength)

        // The shaft stops at the head's base so its round cap never pokes through the tip.
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.strokeLineSegments(between: [from, base])

        context.setFillColor(color.cgColor)
        context.move(to: to)
        context.addLine(to: CGPoint(x: base.x - uy * headHalfWidth, y: base.y + ux * headHalfWidth))
        context.addLine(to: CGPoint(x: base.x + uy * headHalfWidth, y: base.y - ux * headHalfWidth))
        context.closePath()
        context.fillPath()
    }

    private static func drawText(_ string: String, origin: CGPoint, fontSize: CGFloat, color: RGBAColor, in context: CGContext) {
        let font = CTFontCreateUIFontForLanguage(.system, fontSize, nil) ?? CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        let ascent = CTFontGetAscent(font)
        let lineHeight = ascent + CTFontGetDescent(font) + CTFontGetLeading(font)

        context.textMatrix = .identity
        for (index, line) in string.components(separatedBy: .newlines).enumerated() {
            let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: attributes))
            context.saveGState()
            // CoreText draws y-up; flip locally around the baseline so text is upright in our y-down space.
            context.translateBy(x: origin.x, y: origin.y + ascent + CGFloat(index) * lineHeight)
            context.scaleBy(x: 1, y: -1)
            context.textPosition = .zero
            CTLineDraw(ctLine, context)
            context.restoreGState()
        }
    }
}
