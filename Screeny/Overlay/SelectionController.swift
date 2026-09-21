import CoreGraphics

enum SelectionHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    var adjustsMinX: Bool { self == .topLeft || self == .left || self == .bottomLeft }
    var adjustsMaxX: Bool { self == .topRight || self == .right || self == .bottomRight }
    var adjustsMinY: Bool { self == .topLeft || self == .top || self == .topRight }
    var adjustsMaxY: Bool { self == .bottomLeft || self == .bottom || self == .bottomRight }
}

/// Create / move / resize logic for the selection rect, in flipped overlay view points.
struct SelectionController: Sendable {
    static let handleHitRadius: CGFloat = 6
    static let minimumSize: CGFloat = 3

    private enum Drag: Sendable {
        case creating(anchor: CGPoint)
        case moving(start: CGPoint, original: CGRect)
        case resizing(SelectionHandle, start: CGPoint, original: CGRect)
    }

    let bounds: CGRect
    let scale: CGFloat
    private(set) var rect: CGRect?
    private var drag: Drag?

    init(bounds: CGRect, scale: CGFloat) {
        self.bounds = bounds
        self.scale = scale
    }

    var isDragging: Bool { drag != nil }

    var isCreating: Bool {
        if case .creating = drag { return true }
        return false
    }

    var isMoving: Bool {
        if case .moving = drag { return true }
        return false
    }

    static func handlePoint(_ handle: SelectionHandle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .top: CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .right: CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .left: CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    func handle(at point: CGPoint) -> SelectionHandle? {
        guard let rect else { return nil }
        return SelectionHandle.allCases.first { handle in
            let center = Self.handlePoint(handle, in: rect)
            return abs(center.x - point.x) <= Self.handleHitRadius && abs(center.y - point.y) <= Self.handleHitRadius
        }
    }

    mutating func beginCreating(at point: CGPoint) {
        rect = nil
        drag = .creating(anchor: clamped(point))
    }

    mutating func beginMoving(at point: CGPoint) {
        guard let rect else { return }
        drag = .moving(start: point, original: rect)
    }

    mutating func beginResizing(_ handle: SelectionHandle, at point: CGPoint) {
        guard let rect else { return }
        drag = .resizing(handle, start: point, original: rect)
    }

    mutating func update(to point: CGPoint) {
        switch drag {
        case let .creating(anchor):
            let end = clamped(point)
            rect = snapped(CGRect(
                x: min(anchor.x, end.x), y: min(anchor.y, end.y),
                width: abs(end.x - anchor.x), height: abs(end.y - anchor.y)
            ))
        case let .moving(start, original):
            var moved = original.offsetBy(dx: point.x - start.x, dy: point.y - start.y)
            moved.origin.x = max(bounds.minX, min(moved.minX, bounds.maxX - moved.width))
            moved.origin.y = max(bounds.minY, min(moved.minY, bounds.maxY - moved.height))
            rect = snapped(moved)
        case let .resizing(handle, start, original):
            let dx = point.x - start.x
            let dy = point.y - start.y
            var minX = original.minX, maxX = original.maxX, minY = original.minY, maxY = original.maxY
            if handle.adjustsMinX { minX += dx }
            if handle.adjustsMaxX { maxX += dx }
            if handle.adjustsMinY { minY += dy }
            if handle.adjustsMaxY { maxY += dy }
            let a = clamped(CGPoint(x: minX, y: minY))
            let b = clamped(CGPoint(x: maxX, y: maxY))
            // Dragging an edge past its opposite flips the rect instead of collapsing it.
            rect = snapped(CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y)))
        case nil:
            break
        }
    }

    mutating func end() {
        if isCreating, let rect, rect.width < Self.minimumSize || rect.height < Self.minimumSize {
            self.rect = nil
        }
        drag = nil
    }

    mutating func clear() {
        rect = nil
        drag = nil
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX), y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    /// Keeps the rect on the backing pixel grid, so moving it shifts annotations by whole pixels.
    private func snapped(_ rect: CGRect) -> CGRect {
        let snap = { (value: CGFloat) in (value * scale).rounded() / scale }
        let minX = snap(rect.minX), minY = snap(rect.minY)
        return CGRect(x: minX, y: minY, width: snap(rect.maxX) - minX, height: snap(rect.maxY) - minY)
    }
}
