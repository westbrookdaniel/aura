import AppKit
import Darwin
import Foundation

enum IconGenerationError: LocalizedError {
    case missingOutputPath
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .missingOutputPath:
            return "Usage: GenerateAppIcon.swift <output-icns-path>"
        case .imageEncodingFailed:
            return "Failed to encode generated image data."
        }
    }
}

func drawAuraIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: image.size)
    let cornerRadius = size * 0.23
    let tileRect = rect.insetBy(dx: size * 0.06, dy: size * 0.06)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0.15, alpha: 0.14)
    shadow.shadowBlurRadius = size * 0.045
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.02)
    shadow.set()
    NSColor(calibratedWhite: 0.98, alpha: 1.0).setFill()
    tile.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let auraRect = tileRect.insetBy(dx: -size * 0.18, dy: -size * 0.08)
    let center = NSPoint(x: tileRect.midX, y: tileRect.minY - size * 0.06)
    NSGraphicsContext.current?.saveGraphicsState()
    tile.addClip()
    drawAuraGradient(in: auraRect, center: center)
    NSGraphicsContext.current?.restoreGraphicsState()

    let glyphRect = tileRect.insetBy(dx: size * 0.18, dy: size * 0.18)
    let glyphPath = waveformGlyphPath(in: glyphRect)
    NSColor.black.setFill()
    glyphPath.fill()

    image.unlockFocus()
    return image
}

func drawAuraGradient(in rect: NSRect, center: NSPoint) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let colors = [
        NSColor(calibratedRed: 0.55, green: 0.82, blue: 1.00, alpha: 0.88).cgColor,
        NSColor(calibratedRed: 0.55, green: 0.82, blue: 1.00, alpha: 0.50).cgColor,
        NSColor(calibratedRed: 0.55, green: 0.82, blue: 1.00, alpha: 0.18).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor
    ] as CFArray

    guard let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0.0, 0.24, 0.58, 1.0]
    ) else {
        return
    }

    let radius = max(rect.width, rect.height) * 0.96
    context.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: center.x, y: center.y),
        startRadius: 0,
        endCenter: CGPoint(x: center.x, y: center.y),
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
}

func waveformGlyphPath(in rect: NSRect) -> NSBezierPath {
    let width = rect.width
    let height = rect.height
    let barWidth = width * 0.115
    let spacing = width * 0.072
    let heights: [CGFloat] = [0.35, 0.60, 0.92, 0.60, 0.35]
    let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * spacing
    let startX = rect.minX + (width - totalWidth) / 2
    let path = NSBezierPath()

    for (index, factor) in heights.enumerated() {
        let barHeight = height * factor
        let x = startX + CGFloat(index) * (barWidth + spacing)
        let y = rect.minY + (height - barHeight) / 2
        let barRect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
        path.appendRoundedRect(barRect, xRadius: barWidth / 2, yRadius: barWidth / 2)
    }

    return path
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}

func writePNG(image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw IconGenerationError.imageEncodingFailed
    }

    try pngData.write(to: url)
}

func generateAppIcon() throws {
    guard CommandLine.arguments.count > 1 else {
        throw IconGenerationError.missingOutputPath
    }

    let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let fileManager = FileManager.default
    let iconsetURL = fileManager.temporaryDirectory
        .appendingPathComponent("AuraAppIcon-\(UUID().uuidString)")
        .appendingPathExtension("iconset")
    let previewURL = outputURL.deletingLastPathComponent().appendingPathComponent("AuraIconPreview.png")

    if fileManager.fileExists(atPath: iconsetURL.path) {
        try fileManager.removeItem(at: iconsetURL)
    }

    if fileManager.fileExists(atPath: outputURL.path) {
        try fileManager.removeItem(at: outputURL)
    }

    try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

    let iconSizes: [(String, CGFloat)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    for (filename, size) in iconSizes {
        try writePNG(image: drawAuraIcon(size: size), to: iconsetURL.appendingPathComponent(filename))
    }

    try writePNG(image: drawAuraIcon(size: 1024), to: previewURL)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        fputs("warning: iconutil failed with exit status \(process.terminationStatus); generated PNG previews remain available.\n", stderr)
    }

    try? fileManager.removeItem(at: iconsetURL)
}

do {
    try generateAppIcon()
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    Darwin.exit(1)
}
