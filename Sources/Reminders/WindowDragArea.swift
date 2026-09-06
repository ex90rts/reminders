import AppKit

final class WindowDragAreaView: NSView {
    var onScroll: ((NSEvent) -> Void)?

    override var mouseDownCanMoveWindow: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        if let onScroll {
            onScroll(event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }
}
