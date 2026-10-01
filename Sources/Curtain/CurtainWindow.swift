import AppKit
import CurtainCore

/// A black, borderless panel over one screen, above everything including the menu bar, the Dock,
/// full-screen apps and notifications. It takes the keyboard without activating the app, swallows
/// every key, click and scroll, and hands Esc to `onEscape`.
final class CurtainWindow: NSPanel {
    var onEscape: (() -> Void)?

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        alphaValue = 0
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isMovable = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let view = CurtainView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onEscape = { [weak self] in self?.onEscape?() }
        contentView = view
        initialFirstResponder = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

private final class CurtainView: NSView {
    var onEscape: (() -> Void)?
    private static let blankCursor = NSCursor(image: NSImage(size: NSSize(width: 1, height: 1)), hotSpot: .zero)

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) { NSColor.black.setFill(); dirtyRect.fill() }
    override func resetCursorRects() { addCursorRect(bounds, cursor: Self.blankCursor) }

    override func keyDown(with event: NSEvent) {
        if WakeKey.wakes(keyCode: event.keyCode) { onEscape?() }
    }
    override func keyUp(with event: NSEvent) {}
    override func flagsChanged(with event: NSEvent) {}
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
    override func cancelOperation(_ sender: Any?) {}
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
}
