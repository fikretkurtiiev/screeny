import CoreGraphics
@testable import Screeny
import Testing

struct AnnotationDocumentTests {
    private let first = Annotation.line(from: .zero, to: CGPoint(x: 10, y: 10), color: .red, width: 2)
    private let second = Annotation.rectangle(rect: CGRect(x: 1, y: 2, width: 3, height: 4), color: .blue, width: 1)

    @Test func startsEmptyWithNoHistory() {
        let document = AnnotationDocument()
        #expect(document.isEmpty)
        #expect(!document.canUndo)
        #expect(!document.canRedo)
    }

    @Test func undoRestoresPreviousSnapshot() {
        var document = AnnotationDocument()
        document.add(first)
        document.add(second)
        document.undo()
        #expect(document.annotations == [first])
        #expect(document.canRedo)
    }

    @Test func redoReappliesUndoneAnnotation() {
        var document = AnnotationDocument()
        document.add(first)
        document.undo()
        document.redo()
        #expect(document.annotations == [first])
        #expect(!document.canRedo)
    }

    @Test func addingClearsRedo() {
        var document = AnnotationDocument()
        document.add(first)
        document.undo()
        document.add(second)
        #expect(!document.canRedo)
        #expect(document.annotations == [second])
    }

    @Test func undoOnEmptyHistoryIsNoOp() {
        var document = AnnotationDocument()
        document.undo()
        document.redo()
        #expect(document == AnnotationDocument())
    }

    @Test func translateShiftsHistoryToo() {
        var document = AnnotationDocument()
        document.add(first)
        document.add(second)
        document.translate(dx: 5, dy: -1)
        document.undo()
        #expect(document.annotations == [first.offsetBy(dx: 5, dy: -1)])
        document.redo()
        #expect(document.annotations == [first, second].map { $0.offsetBy(dx: 5, dy: -1) })
    }
}
