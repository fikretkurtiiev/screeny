import CoreGraphics

/// Places the toolbar next to the selection, in flipped overlay view points.
enum ToolbarLayout {
    static let gap: CGFloat = 8

    /// Prefers below the selection (right-aligned), then above, then inside its bottom edge.
    static func frame(for size: CGSize, selection: CGRect, bounds: CGRect) -> CGRect {
        let x = max(bounds.minX + gap, min(selection.maxX - size.width, bounds.maxX - size.width - gap))

        let below = selection.maxY + gap
        if below + size.height <= bounds.maxY - gap {
            return CGRect(origin: CGPoint(x: x, y: below), size: size)
        }
        let above = selection.minY - gap - size.height
        if above >= bounds.minY + gap {
            return CGRect(origin: CGPoint(x: x, y: above), size: size)
        }
        let inside = max(bounds.minY + gap, selection.maxY - gap - size.height)
        return CGRect(origin: CGPoint(x: x, y: inside), size: size)
    }
}
