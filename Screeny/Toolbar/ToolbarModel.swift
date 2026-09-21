import CoreGraphics
import Observation

/// Stroke width in points; the overlay converts to pixels.
enum StrokeWidth: CGFloat, CaseIterable, Sendable {
    case thin = 2
    case medium = 4
    case thick = 8
}

@MainActor
@Observable
final class ToolbarModel {
    var tool: Tool?
    var color: RGBAColor = .red
    var width: StrokeWidth = .medium
    var canUndo = false
    var canRedo = false

    @ObservationIgnored var onToolChange: () -> Void = {}
    @ObservationIgnored var onStyleChange: () -> Void = {}
    @ObservationIgnored var onCustomColor: () -> Void = {}
    @ObservationIgnored var onUndo: () -> Void = {}
    @ObservationIgnored var onRedo: () -> Void = {}
    @ObservationIgnored var onCopy: () -> Void = {}
    @ObservationIgnored var onSave: () -> Void = {}
    @ObservationIgnored var onCancel: () -> Void = {}

    /// Selecting the active tool again deselects it, returning to move/resize mode.
    func select(_ newTool: Tool) {
        tool = tool == newTool ? nil : newTool
        onToolChange()
    }

    func setColor(_ newColor: RGBAColor) {
        color = newColor
        onStyleChange()
    }

    func setWidth(_ newWidth: StrokeWidth) {
        width = newWidth
        onStyleChange()
    }
}
