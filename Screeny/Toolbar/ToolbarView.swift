import SwiftUI

extension Tool {
    var symbolName: String {
        switch self {
        case .pen: "scribble"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .marker: "highlighter"
        case .text: "textformat"
        }
    }

    var title: String {
        switch self {
        case .pen: "Pen"
        case .line: "Line"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .marker: "Marker"
        case .text: "Text"
        }
    }
}

/// Everything is inline: menus and popovers would open beneath the .screenSaver-level overlay.
struct ToolbarView: View {
    let model: ToolbarModel

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Tool.allCases, id: \.self) { tool in
                ToolbarButton(systemImage: tool.symbolName, help: tool.title, isSelected: model.tool == tool) {
                    model.select(tool)
                }
            }
            ToolbarDivider()
            ForEach(RGBAColor.palette, id: \.self) { color in
                ColorSwatch(color: color, isSelected: model.color == color) { model.setColor(color) }
            }
            ToolbarButton(
                systemImage: "eyedropper",
                help: "Custom color",
                isSelected: !RGBAColor.palette.contains(model.color)
            ) { model.onCustomColor() }
            ToolbarDivider()
            ForEach(StrokeWidth.allCases, id: \.self) { width in
                WidthButton(width: width, isSelected: model.width == width) { model.setWidth(width) }
            }
            ToolbarDivider()
            ToolbarButton(systemImage: "arrow.uturn.backward", help: "Undo (⌘Z)") { model.onUndo() }
                .disabled(!model.canUndo)
            ToolbarButton(systemImage: "arrow.uturn.forward", help: "Redo (⇧⌘Z)") { model.onRedo() }
                .disabled(!model.canRedo)
            ToolbarDivider()
            ToolbarButton(systemImage: "doc.on.doc", help: "Copy (⌘C)") { model.onCopy() }
            ToolbarButton(systemImage: "square.and.arrow.down", help: "Save (⌘S)") { model.onSave() }
            ToolbarButton(systemImage: "xmark", help: "Cancel (Esc)") { model.onCancel() }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.15)))
        .fixedSize()
    }
}

private struct ToolbarButton: View {
    let systemImage: String
    let help: String
    var isSelected = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.accentColor.opacity(0.25) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .help(help)
    }
}

private struct ColorSwatch: View {
    let color: RGBAColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(cgColor: color.cgColor))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 0.5))
                .frame(width: 14, height: 14)
                .padding(2)
                .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2))
                .frame(width: 20, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct WidthButton: View {
    let width: StrokeWidth
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.primary)
                .frame(width: width.rawValue + 2, height: width.rawValue + 2)
                .frame(width: 22, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.accentColor.opacity(0.25) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(Int(width.rawValue)) pt")
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 3)
    }
}
