// Draws Kalendar's app icon and writes Resources/AppIcon.icns:
// a navy rounded square with an accent-blue calendar page, as in the menu bar glyph.
//   xcrun swift scripts/make-icon.swift
import AppKit

let navy = NSColor(srgbRed: 0x0B / 255, green: 0x11 / 255, blue: 0x19 / 255, alpha: 1)   // Theme background (dark)
let accent = NSColor(srgbRed: 0x00 / 255, green: 0xAA / 255, blue: 0xFF / 255, alpha: 1) // Theme accent

/// The 1024 pt master: Apple's macOS grid puts an 824 pt rounded square in a 1024 pt canvas.
func master() -> NSImage {
    NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
        let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.shadowBlurRadius = 28
        shadow.set()
        navy.setFill()
        NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185).fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        let config = NSImage.SymbolConfiguration(pointSize: 470, weight: .regular)
            .applying(.init(paletteColors: [accent]))
        let glyph = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)!
            .withSymbolConfiguration(config)!
        let size = glyph.size
        glyph.draw(in: NSRect(x: 512 - size.width / 2, y: 512 - size.height / 2, width: size.width, height: size.height))
        return true
    }
}

func png(_ image: NSImage, pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let image = master()
for points in [16, 32, 128, 256, 512] {
    try png(image, pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(image, pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let out = URL(fileURLWithPath: "Resources/AppIcon.icns")
try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "wrote \(out.path)" : "iconutil failed")
