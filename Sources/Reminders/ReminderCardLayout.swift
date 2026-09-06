import CoreGraphics

/// A single source of truth for dimensions that should follow the reminder font size.
struct ReminderCardLayout: Equatable {
    static let panelWidth = CGFloat(AppConfiguration.defaultReminderWidth)
    static let contentInset: CGFloat = 28

    let scale: CGFloat
    let panelWidth: CGFloat

    init(fontSize: Double, panelWidth: Double = AppConfiguration.defaultReminderWidth) {
        scale = CGFloat(fontSize / AppConfiguration.defaultReminderFontSize)
        self.panelWidth = CGFloat(panelWidth)
    }

    var numberFontSize: CGFloat { 11 * scale }
    var numberDiameter: CGFloat { 18 * scale }
    var contentSpacing: CGFloat { 9 * scale }
    var horizontalPadding: CGFloat { 16 * scale }
    var verticalPadding: CGFloat { 15 * scale }
    var cornerRadius: CGFloat { 18 * scale }
    var cardSpacing: CGFloat { 12 * scale }

    var availableTextWidth: CGFloat {
        panelWidth
            - Self.contentInset * 2
            - horizontalPadding * 2
            - numberDiameter
            - contentSpacing
    }
}
