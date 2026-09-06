import AppKit
import Combine

@MainActor
final class OverlayWindowController: NSObject, NSWindowDelegate {
    private enum Layout {
        static let minimumHeight: CGFloat = 130
        static let maximumScreenFraction: CGFloat = 0.82
        static let screenEdgeMargin: CGFloat = 28
    }

    private let store: ConfigurationStore
    private let panel = OverlayPanel()
    private var subscription: AnyCancellable?
    private var positionSaveWorkItem: DispatchWorkItem?
    private var lastRenderedConfiguration: AppConfiguration?

    init(store: ConfigurationStore) {
        self.store = store
        super.init()
        panel.delegate = self

        subscription = store.$configuration
            .sink { [weak self] configuration in
                self?.apply(configuration)
            }
    }

    func show() {
        guard !panel.isVisible else { return }
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func resetPosition() {
        store.resetWindowPosition()
        place(at: .topRight)
        saveCurrentOrigin()
    }

    func windowDidMove(_ notification: Notification) {
        positionSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveCurrentOrigin()
        }
        positionSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func apply(_ configuration: AppConfiguration) {
        panel.level = configuration.isAlwaysOnTop ? .floating : .normal

        if configuration.isOverlayVisible && !configuration.visibleItems.isEmpty {
            show()
        } else {
            hide()
        }

        let previousPosition = lastRenderedConfiguration?.residentReminderPosition
        var renderConfiguration = configuration
        renderConfiguration.savedWindowOrigin = nil
        guard renderConfiguration != lastRenderedConfiguration else { return }
        lastRenderedConfiguration = renderConfiguration

        let oldTopLeft = CGPoint(x: panel.frame.minX, y: panel.frame.maxY)
        let size = preferredPanelSize(for: configuration)
        panel.contentView = OverlayContentView(configuration: configuration, size: size)
        panel.setContentSize(size)

        if let savedOrigin = configuration.savedWindowOrigin {
            panel.setFrameOrigin(visibleOrigin(for: savedOrigin.point, windowSize: size))
        } else if previousPosition != configuration.residentReminderPosition || oldTopLeft == .zero {
            place(at: configuration.residentReminderPosition)
        } else {
            panel.setFrameTopLeftPoint(oldTopLeft)
            keepWindowVisible()
        }
    }

    private func preferredPanelSize(for configuration: AppConfiguration) -> CGSize {
        let layout = ReminderCardLayout(
            fontSize: configuration.reminderFontSize,
            panelWidth: configuration.reminderWidth
        )
        let font = NSFont.systemFont(ofSize: configuration.reminderFontSize, weight: .semibold)
        let visibleItems = configuration.visibleItems
        let naturalCardsHeight = visibleItems.reduce(CGFloat.zero) { height, item in
            let displayText = item.text.isEmpty ? "未填写提醒" : item.text
            let textHeight = (displayText as NSString).boundingRect(
                with: CGSize(width: layout.availableTextWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font]
            ).height
            let contentHeight = max(layout.numberDiameter, ceil(textHeight))
            return height + contentHeight + layout.verticalPadding * 2
        }
        let spacings = CGFloat(max(0, visibleItems.count - 1)) * layout.cardSpacing
        let contentInsets = ReminderCardLayout.contentInset * 2
        let naturalHeight = contentInsets + naturalCardsHeight + spacings
        let screenHeight = (panel.screen ?? NSScreen.main)?.visibleFrame.height ?? 900
        let maximumHeight = screenHeight * Layout.maximumScreenFraction
        return CGSize(
            width: CGFloat(configuration.reminderWidth),
            height: min(max(Layout.minimumHeight, naturalHeight), maximumHeight)
        )
    }

    private func place(at position: ResidentReminderPosition) {
        guard let visibleFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return }
        let origin = position.windowOrigin(
            in: visibleFrame,
            windowSize: panel.frame.size,
            margin: Layout.screenEdgeMargin
        )
        panel.setFrameOrigin(origin)
    }

    private func keepWindowVisible() {
        panel.setFrameOrigin(visibleOrigin(for: panel.frame.origin, windowSize: panel.frame.size))
    }

    private func visibleOrigin(for requestedOrigin: CGPoint, windowSize: CGSize) -> CGPoint {
        let matchingScreen = NSScreen.screens.first { screen in
            screen.visibleFrame.insetBy(dx: -windowSize.width / 2, dy: -windowSize.height / 2)
                .contains(requestedOrigin)
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let frame = matchingScreen?.visibleFrame else { return requestedOrigin }
        let maximumX = max(frame.minX, frame.maxX - windowSize.width)
        let maximumY = max(frame.minY, frame.maxY - windowSize.height)
        return CGPoint(
            x: min(max(requestedOrigin.x, frame.minX), maximumX),
            y: min(max(requestedOrigin.y, frame.minY), maximumY)
        )
    }

    private func saveCurrentOrigin() {
        guard panel.frame.origin != .zero else { return }
        store.configuration.savedWindowOrigin = SavedWindowOrigin(
            x: panel.frame.origin.x,
            y: panel.frame.origin.y
        )
    }
}
