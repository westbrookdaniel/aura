import AppKit

enum AuraStatusIcon {
    static func makeTemplateImage(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.isTemplate = true
        image.lockFocus()

        NSColor.labelColor.setFill()
        glyphPath(in: NSRect(x: 0, y: 0, width: size, height: size)).fill()

        image.unlockFocus()
        return image
    }

    private static func glyphPath(in rect: NSRect) -> NSBezierPath {
        let width = rect.width
        let height = rect.height
        let barWidth = width * 0.12
        let spacing = width * 0.07
        let heights: [CGFloat] = [0.36, 0.62, 0.92, 0.62, 0.36]
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
}
