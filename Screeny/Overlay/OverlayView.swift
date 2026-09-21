import AppKit
import SwiftUI

@MainActor
protocol OverlayViewDelegate: AnyObject {
    func overlayViewDidBeginSelection(_ view: OverlayView)
    func overlayViewDidFinishSelection(_ view: OverlayView)
    func overlayViewDidRequestCopy(_ view: OverlayView)
    func overlayViewDidRequestSave(_ view: OverlayView)
    func overlayViewDidRequestCancel(_ view: OverlayView)
}

/// Frozen frame, dim layer, selection chrome and annotation canvas for one display.
final class OverlayView: NSView {
    private struct TextEditor {
        let field: NSTextField
        /// Selection-local pixels.
        let origin: CGPoint
    }

    private static let dimColor = CGColor(gray: 0, alpha: 0.45)
    private static let handleSize: CGFloat = 7
    /// Borderless NSTextField draws its text inset slightly from its frame.
    private static let textFieldInset = CGSize(width: 2, height: 0)
    private static let sizeLabelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
        .foregroundColor: NSColor.white,
    ]

    weak var delegate: OverlayViewDelegate?

    private let image: CGImage
    private let scale: CGFloat
    private var selection: SelectionController
    private var document = AnnotationDocument() {
        didSet {
            toolbarModel.canUndo = document.canUndo
            toolbarModel.canRedo = document.canRedo
            invalidateCanvas()
        }
    }

    private var activeDrag: (any DragTool)?
    private var textEditor: TextEditor?
    private let toolbarModel = ToolbarModel()
    private let colorPanel = ColorPanelBridge()
    private lazy var toolbarHost = NSHostingView(rootView: ToolbarView(model: toolbarModel))
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, image: CGImage, scale: CGFloat) {
        self.image = image
        self.scale = scale
        selection = SelectionController(bounds: CGRect(origin: .zero, size: frame.size), scale: scale)
        super.init(frame: frame)
        configureToolbar()
    }

    required init?(coder _: NSCoder) {
        nil
    }

    /// The one place AppKit's bottom-left origin is converted: everything in this view is top-left, like CGImage.
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }

    var hasSelection: Bool { selection.rect != nil }

    private var space: SelectionSpace? {
        selection.rect.map { SelectionSpace(selection: $0, scale: scale) }
    }

    private var pixelStyle: ToolStyle {
        ToolStyle(color: toolbarModel.color, width: toolbarModel.width.rawValue * scale)
    }

    private var textFontSize: CGFloat {
        TextTool.fontSize(forStrokeWidth: toolbarModel.width.rawValue)
    }

    // MARK: Session API

    func renderSelection() -> CGImage? {
        commitTextEditing()
        guard let space else { return nil }
        return Exporter.flatten(image: image, cropRect: space.imagePixelRect, annotations: document.annotations)
    }

    func clearSelection() {
        guard selection.rect != nil else { return }
        discardTextEditing()
        activeDrag = nil
        selection.clear()
        document = AnnotationDocument()
        needsDisplay = true
        layoutToolbar()
    }

    func tearDown() {
        colorPanel.close()
    }

    // MARK: Drawing

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: bounds)
        context.restoreGState()

        context.setFillColor(Self.dimColor)
        context.addRect(bounds)
        if let rect = selection.rect {
            context.addRect(rect)
        }
        context.fillPath(using: .evenOdd)

        guard let rect = selection.rect else { return }
        drawAnnotations(in: context, selection: rect)
        drawChrome(in: context, selection: rect)
    }

    private func drawAnnotations(in context: CGContext, selection rect: CGRect) {
        var annotations = document.annotations
        if let preview = activeDrag?.annotation {
            annotations.append(preview)
        }
        guard !annotations.isEmpty else { return }
        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: 1 / scale, y: 1 / scale)
        Renderer.draw(annotations, in: context)
        context.restoreGState()
    }

    private func drawChrome(in context: CGContext, selection rect: CGRect) {
        context.setStrokeColor(CGColor.white)
        context.setLineWidth(1)
        context.stroke(rect.insetBy(dx: -0.5, dy: -0.5))

        context.setFillColor(CGColor.white)
        context.setStrokeColor(CGColor(gray: 0.3, alpha: 1))
        for handle in SelectionHandle.allCases {
            let center = SelectionController.handlePoint(handle, in: rect)
            let size = Self.handleSize
            let handleRect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
            context.fill(handleRect)
            context.stroke(handleRect.insetBy(dx: 0.5, dy: 0.5))
        }

        let (labelRect, label) = sizeLabel(for: rect)
        context.setFillColor(CGColor(gray: 0, alpha: 0.7))
        context.addPath(CGPath(roundedRect: labelRect, cornerWidth: 4, cornerHeight: 4, transform: nil))
        context.fillPath()
        label.draw(at: CGPoint(x: labelRect.minX + 6, y: labelRect.minY + 3))
    }

    private func sizeLabel(for rect: CGRect) -> (CGRect, NSAttributedString) {
        let size = SelectionSpace(selection: rect, scale: scale).pixelSize
        let label = NSAttributedString(string: "\(Int(size.width)) × \(Int(size.height))", attributes: Self.sizeLabelAttributes)
        let textSize = label.size()
        var labelRect = CGRect(x: rect.minX, y: rect.minY - textSize.height - 12, width: textSize.width + 12, height: textSize.height + 6)
        if labelRect.minY < bounds.minY + 2 {
            labelRect.origin = CGPoint(x: rect.minX + 6, y: rect.minY + 6)
        }
        return (labelRect.integral, label)
    }

    private func chromeBounds(for rect: CGRect?) -> CGRect? {
        guard let rect else { return nil }
        let margin = Self.handleSize + 2
        return rect.insetBy(dx: -margin, dy: -margin).union(sizeLabel(for: rect).0.insetBy(dx: -2, dy: -2))
    }

    private func invalidateCanvas() {
        if let rect = selection.rect {
            setNeedsDisplay(rect)
        }
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        commitTextEditing()

        if let rect = selection.rect {
            if let handle = selection.handle(at: point) {
                mutateSelection { $0.beginResizing(handle, at: point) }
                return
            }
            if rect.contains(point) {
                beginInteractionInsideSelection(at: point)
                return
            }
            // Starting over would strand annotations that belong to the current selection.
            guard document.isEmpty else { return }
        }
        delegate?.overlayViewDidBeginSelection(self)
        mutateSelection { $0.beginCreating(at: point) }
    }

    private func beginInteractionInsideSelection(at point: CGPoint) {
        guard let space, let tool = toolbarModel.tool else {
            NSCursor.closedHand.set()
            mutateSelection { $0.beginMoving(at: point) }
            return
        }
        if tool == .text {
            beginTextEditing(at: point)
            return
        }
        activeDrag = tool.beginDrag(at: space.pixelPoint(fromViewPoint: point), style: pixelStyle)
        invalidateCanvas()
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if activeDrag != nil, let space {
            activeDrag?.drag(to: space.pixelPoint(fromViewPoint: point), constrained: event.modifierFlags.contains(.shift))
            invalidateCanvas()
        } else if selection.isDragging {
            mutateSelection { $0.update(to: point) }
        }
    }

    override func mouseUp(with event: NSEvent) {
        if let drag = activeDrag {
            activeDrag = nil
            if let annotation = drag.annotation {
                document.add(annotation)
            } else {
                invalidateCanvas()
            }
            return
        }
        guard selection.isDragging else { return }
        mutateSelection { $0.end() }
        delegate?.overlayViewDidFinishSelection(self)
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    private func mutateSelection(_ change: (inout SelectionController) -> Void) {
        let old = selection.rect
        change(&selection)
        let new = selection.rect
        if let old, let new, old.origin != new.origin, !selection.isCreating {
            // Annotations are selection-local; shift them so they stay pinned to the frozen image.
            document.translate(dx: ((old.minX - new.minX) * scale).rounded(), dy: ((old.minY - new.minY) * scale).rounded())
        }
        if old != new {
            if let dirty = chromeBounds(for: old) { setNeedsDisplay(dirty) }
            if let dirty = chromeBounds(for: new) { setNeedsDisplay(dirty) }
        }
        layoutToolbar()
    }

    // MARK: Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .inVisibleRect], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    private func updateCursor(at point: CGPoint) {
        cursor(at: point).set()
    }

    private func cursor(at point: CGPoint) -> NSCursor {
        if !toolbarHost.isHidden, toolbarHost.frame.contains(point) { return .arrow }
        guard let rect = selection.rect else { return .crosshair }
        if let handle = selection.handle(at: point) {
            switch handle {
            case .left, .right: return .resizeLeftRight
            case .top, .bottom: return .resizeUpDown
            default: return .crosshair
            }
        }
        if rect.contains(point) {
            switch toolbarModel.tool {
            case nil: return .openHand
            case .text: return .iBeam
            default: return .crosshair
            }
        }
        return document.isEmpty ? .crosshair : .arrow
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        // 53 is Escape.
        if event.keyCode == 53 {
            delegate?.overlayViewDidRequestCancel(self)
        } else {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard textEditor == nil, window?.isKeyWindow == true,
              let key = event.charactersIgnoringModifiers?.lowercased()
        else { return super.performKeyEquivalent(with: event) }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if flags == .command, key == "c" {
            requestCopy()
        } else if flags == .command, key == "s" {
            requestSave()
        } else if flags == .command, key == "z" {
            document.undo()
        } else if flags == [.command, .shift], key == "z" {
            document.redo()
        } else {
            return super.performKeyEquivalent(with: event)
        }
        return true
    }

    private func requestCopy() {
        guard hasSelection else { return NSSound.beep() }
        delegate?.overlayViewDidRequestCopy(self)
    }

    private func requestSave() {
        guard hasSelection else { return NSSound.beep() }
        delegate?.overlayViewDidRequestSave(self)
    }

    // MARK: Toolbar

    private func configureToolbar() {
        toolbarHost.isHidden = true
        addSubview(toolbarHost)

        toolbarModel.onToolChange = { [weak self] in self?.commitTextEditing() }
        toolbarModel.onStyleChange = { [weak self] in self?.applyTextStyle() }
        toolbarModel.onCustomColor = { [weak self] in
            guard let self else { return }
            colorPanel.show(initial: toolbarModel.color)
        }
        toolbarModel.onUndo = { [weak self] in self?.document.undo() }
        toolbarModel.onRedo = { [weak self] in self?.document.redo() }
        toolbarModel.onCopy = { [weak self] in self?.requestCopy() }
        toolbarModel.onSave = { [weak self] in self?.requestSave() }
        toolbarModel.onCancel = { [weak self] in
            guard let self else { return }
            delegate?.overlayViewDidRequestCancel(self)
        }
        colorPanel.onChange = { [weak self] color in self?.toolbarModel.setColor(color) }
    }

    private func layoutToolbar() {
        guard let rect = selection.rect, !selection.isDragging else {
            toolbarHost.isHidden = true
            return
        }
        toolbarHost.frame = ToolbarLayout.frame(for: toolbarHost.fittingSize, selection: rect, bounds: bounds)
        toolbarHost.isHidden = false
    }

    // MARK: Text

    private func beginTextEditing(at point: CGPoint) {
        guard let space else { return }
        let field = NSTextField(string: "")
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.maximumNumberOfLines = 1
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = self
        field.frame.origin = CGPoint(x: point.x - Self.textFieldInset.width, y: point.y - Self.textFieldInset.height)
        addSubview(field, positioned: .below, relativeTo: toolbarHost)
        textEditor = TextEditor(field: field, origin: space.pixelPoint(fromViewPoint: point))
        applyTextStyle()
        window?.makeFirstResponder(field)
    }

    private func applyTextStyle() {
        guard let field = textEditor?.field else { return }
        field.font = NSFont.systemFont(ofSize: textFontSize)
        field.textColor = NSColor(cgColor: toolbarModel.color.cgColor)
        resizeTextField(field)
    }

    private func resizeTextField(_ field: NSTextField) {
        let origin = field.frame.origin
        field.sizeToFit()
        field.frame.origin = origin
        field.frame.size.width = max(field.frame.width + textFontSize, 40)
    }

    private func commitTextEditing() {
        guard let editor = textEditor else { return }
        textEditor = nil
        let string = editor.field.stringValue
        editor.field.removeFromSuperview()
        window?.makeFirstResponder(self)
        if let annotation = TextTool.annotation(
            string: string,
            origin: editor.origin,
            fontSize: textFontSize * scale,
            color: toolbarModel.color
        ) {
            document.add(annotation)
        }
    }

    private func discardTextEditing() {
        guard let editor = textEditor else { return }
        textEditor = nil
        editor.field.removeFromSuperview()
        window?.makeFirstResponder(self)
    }
}

extension OverlayView: NSTextFieldDelegate {
    func controlTextDidChange(_: Notification) {
        guard let field = textEditor?.field else { return }
        resizeTextField(field)
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            commitTextEditing()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            discardTextEditing()
            return true
        default:
            return false
        }
    }
}
