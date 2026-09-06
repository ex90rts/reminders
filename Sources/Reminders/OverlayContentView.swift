import AppKit
import SwiftUI

/// Keeps window interaction in AppKit instead of relying on SwiftUI hit testing.
final class OverlayContentView: NSView {
    let dragArea = WindowDragAreaView()
    private let hostingView: NSHostingView<ReminderBoardView>

    init(configuration: AppConfiguration, size: CGSize) {
        hostingView = NSHostingView(rootView: ReminderBoardView(configuration: configuration))
        super.init(frame: CGRect(origin: .zero, size: size))

        hostingView.sizingOptions = []
        addSubview(hostingView)

        dragArea.onScroll = { [weak hostingView] event in
            hostingView?.scrollWheel(with: event)
        }
        addSubview(dragArea, positioned: .above, relativeTo: hostingView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        hostingView.frame = bounds
        dragArea.frame = bounds

        if let window {
            window.invalidateCursorRects(for: dragArea)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? dragArea : nil
    }
}
