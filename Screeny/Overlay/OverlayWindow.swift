import AppKit

/// Borderless panel covering one screen, above everything including full-screen apps.
final class OverlayWindow: NSPanel {
    let overlayView: OverlayView

    init(screen: NSScreen, image: CGImage) {
        overlayView = OverlayView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            image: image,
            scale: screen.backingScaleFactor
        )
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        hasShadow = false
        isOpaque = true
        backgroundColor = .black
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        contentView = overlayView
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // The default would push the frame below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to _: NSScreen?) -> NSRect {
        frameRect
    }
}
