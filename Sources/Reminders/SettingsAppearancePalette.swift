import AppKit
import SwiftUI

enum SettingsAppearancePalette {
    static var windowBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var contentBackgroundNSColor: NSColor {
        .windowBackgroundColor
    }

    static var contentBackground: Color {
        Color(nsColor: contentBackgroundNSColor)
    }

    static var controlSurfaceNSColor: NSColor {
        .controlBackgroundColor
    }

    static var controlSurface: Color {
        Color(nsColor: controlSurfaceNSColor)
    }

    static var shadow: Color {
        Color(nsColor: .shadowColor)
    }
}
