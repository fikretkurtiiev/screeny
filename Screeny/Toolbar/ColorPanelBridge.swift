import AppKit

/// Drives the shared NSColorPanel for the custom color button.
@MainActor
final class ColorPanelBridge: NSObject {
    var onChange: (RGBAColor) -> Void = { _ in }
    /// The panel is shared app-wide; only close it if this bridge opened it.
    private var isShowing = false

    func show(initial: RGBAColor) {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = NSColor(cgColor: initial.cgColor) ?? .red
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        // The overlay sits at .screenSaver level; the panel must float above it to be usable.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.orderFrontRegardless()
        isShowing = true
    }

    func close() {
        guard isShowing, NSColorPanel.sharedColorPanelExists else { return }
        isShowing = false
        let panel = NSColorPanel.shared
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.orderOut(nil)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        guard let color = sender.color.usingColorSpace(.sRGB) else { return }
        onChange(RGBAColor(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent))
    }
}
