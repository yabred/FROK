import AppKit

enum StatusBarIcon {
    private static let menuBarPointSize: CGFloat = 19
    private static var tintedCache: [Int: NSImage] = [:]

    static func templateImage() -> NSImage {
        sizedTemplateImage()
    }

    static func playingImage(accentIndex: Int, color: NSColor) -> NSImage {
        if let cached = tintedCache[accentIndex] {
            return cached
        }

        let tinted = sizedTemplateImage()
        tinted.lockFocus()
        color.set()
        NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false

        tintedCache[accentIndex] = tinted
        return tinted
    }

    private static func sizedTemplateImage() -> NSImage {
        guard let image = (NSImage(named: "status_icon")?.copy() as? NSImage) else {
            return NSImage()
        }

        let size = NSSize(width: menuBarPointSize, height: menuBarPointSize)
        image.size = size
        image.isTemplate = true
        return image
    }
}
