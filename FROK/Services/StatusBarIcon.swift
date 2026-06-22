import AppKit

enum StatusBarIcon {
    private static let menuBarPointSize: CGFloat = 20
    private static var tintedCache: [Int: NSImage] = [:]

    private static let templateBase: NSImage = {
        guard let image = NSImage(named: "status_icon")?.copy() as? NSImage else {
            return NSImage()
        }
        image.size = NSSize(width: menuBarPointSize, height: menuBarPointSize)
        image.isTemplate = true
        return image
    }()

    static func playingImage(accentIndex: Int, color: NSColor) -> NSImage {
        if let cached = tintedCache[accentIndex] {
            return cached
        }

        guard let tinted = templateBase.copy() as? NSImage else {
            return templateBase
        }

        tinted.lockFocus()
        color.set()
        NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false

        tintedCache[accentIndex] = tinted
        return tinted
    }
}
