import AppKit
import Darwin
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: ApplyBundleIcon.swift <icon-image-path> <bundle-path>\n", stderr)
    Darwin.exit(1)
}

let iconURL = URL(fileURLWithPath: CommandLine.arguments[1])
let bundleURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let image = NSImage(contentsOf: iconURL) else {
    fputs("Failed to load icon image at \(iconURL.path).\n", stderr)
    Darwin.exit(1)
}

guard NSWorkspace.shared.setIcon(image, forFile: bundleURL.path, options: []) else {
    fputs("Failed to apply bundle icon to \(bundleURL.path).\n", stderr)
    Darwin.exit(1)
}
