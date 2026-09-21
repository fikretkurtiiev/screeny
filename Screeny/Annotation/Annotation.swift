import CoreGraphics

/// sRGB color stored as components so annotations stay plain, comparable values.
struct RGBAColor: Hashable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat = 1

    var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    func withAlpha(_ alpha: CGFloat) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    static let red = RGBAColor(red: 0.96, green: 0.22, blue: 0.20)
    static let orange = RGBAColor(red: 1.00, green: 0.58, blue: 0.00)
    static let yellow = RGBAColor(red: 1.00, green: 0.84, blue: 0.04)
    static let green = RGBAColor(red: 0.20, green: 0.78, blue: 0.35)
    static let blue = RGBAColor(red: 0.04, green: 0.52, blue: 1.00)
    static let purple = RGBAColor(red: 0.69, green: 0.32, blue: 0.87)
    static let black = RGBAColor(red: 0, green: 0, blue: 0)
    static let white = RGBAColor(red: 1, green: 1, blue: 1)

    static let palette: [RGBAColor] = [.red, .orange, .yellow, .green, .blue, .purple, .black, .white]
}

enum Tool: String, CaseIterable, Sendable {
    case pen
    case line
    case arrow
    case rectangle
    case marker
    case text
}

/// All geometry is in selection-local pixel coordinates with a top-left origin.
enum Annotation: Equatable, Sendable {
    case stroke(points: [CGPoint], color: RGBAColor, width: CGFloat)
    case marker(points: [CGPoint], color: RGBAColor, width: CGFloat)
    case line(from: CGPoint, to: CGPoint, color: RGBAColor, width: CGFloat)
    case arrow(from: CGPoint, to: CGPoint, color: RGBAColor, width: CGFloat)
    case rectangle(rect: CGRect, color: RGBAColor, width: CGFloat)
    case text(string: String, origin: CGPoint, fontSize: CGFloat, color: RGBAColor)

    func offsetBy(dx: CGFloat, dy: CGFloat) -> Annotation {
        let move = { (point: CGPoint) in CGPoint(x: point.x + dx, y: point.y + dy) }
        switch self {
        case let .stroke(points, color, width):
            return .stroke(points: points.map(move), color: color, width: width)
        case let .marker(points, color, width):
            return .marker(points: points.map(move), color: color, width: width)
        case let .line(from, to, color, width):
            return .line(from: move(from), to: move(to), color: color, width: width)
        case let .arrow(from, to, color, width):
            return .arrow(from: move(from), to: move(to), color: color, width: width)
        case let .rectangle(rect, color, width):
            return .rectangle(rect: rect.offsetBy(dx: dx, dy: dy), color: color, width: width)
        case let .text(string, origin, fontSize, color):
            return .text(string: string, origin: move(origin), fontSize: fontSize, color: color)
        }
    }
}
