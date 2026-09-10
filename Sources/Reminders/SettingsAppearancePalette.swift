import AppKit
import SwiftUI

enum SettingsAppearancePalette {
    static var windowBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var contentBackground: Color {
        windowBackground
    }

    static var controlSurface: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var shadow: Color {
        Color(nsColor: .shadowColor)
    }
}
