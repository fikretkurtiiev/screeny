import CoreGraphics

/// The annotation list plus snapshot-based undo/redo history.
struct AnnotationDocument: Equatable, Sendable {
    private(set) var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []

    var isEmpty: Bool { annotations.isEmpty }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func add(_ annotation: Annotation) {
        undoStack.append(annotations)
        redoStack.removeAll()
        annotations.append(annotation)
    }

    mutating func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
    }

    mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
    }

    /// Shifts every annotation, including history, so they stay pinned to the image when the selection origin moves.
    mutating func translate(dx: CGFloat, dy: CGFloat) {
        guard dx != 0 || dy != 0 else { return }
        let shift = { (snapshot: [Annotation]) in snapshot.map { $0.offsetBy(dx: dx, dy: dy) } }
        annotations = shift(annotations)
        undoStack = undoStack.map(shift)
        redoStack = redoStack.map(shift)
    }
}
