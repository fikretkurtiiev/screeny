import CoreGraphics
import Foundation

/// Text is click-to-place rather than drag-based; the overlay hosts the editing field and uses these rules.
enum TextTool {
    /// Font size in points for a stroke width in points, so the width control doubles as text size.
    static func fontSize(forStrokeWidth width: CGFloat) -> CGFloat {
        12 + width * 2
    }

    /// Nil when there's nothing but whitespace, so an abandoned text field leaves no annotation behind.
    static func annotation(string: String, origin: CGPoint, fontSize: CGFloat, color: RGBAColor) -> Annotation? {
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return .text(string: string, origin: origin, fontSize: fontSize, color: color)
    }
}
