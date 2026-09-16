import AppKit
import SwiftUI

enum SettingsAppearancePalette {
    static var windowBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var contentBackground: Color {
        Color(nsColor: .underPageBackgroundColor)
    }

    static var controlSurface: Color {
        windowBackground
    }

    static var shadow: Color {
        Color(nsColor: .shadowColor)
    }
}
