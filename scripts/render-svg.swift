import AppKit
import Foundation

guard CommandLine.arguments.count == 4, let size = Int(CommandLine.arguments[3]) else {
    fputs("Usage: render-svg.swift input.svg output.png size\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let image = NSImage(contentsOf: inputURL) else {
    fputs("Unable to load SVG at \(inputURL.path)\n", stderr)
    exit(1)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to create bitmap context\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Unable to create graphics context\n", stderr)
    exit(1)
}
NSGraphicsContext.current = context
context.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
image.draw(
    in: NSRect(x: 0, y: 0, width: size, height: size),
    from: .zero,
    operation: .copy,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode PNG\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL, options: .atomic)
