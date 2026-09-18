import AppKit
import SwiftUI

enum MenuBarIcon {
    static func image(active: Bool) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let symbol = NSImage(systemSymbolName: "timer", accessibilityDescription: "Kaizen")?
            .withSymbolConfiguration(config) ?? NSImage(size: NSSize(width: 18, height: 18))
        let size = symbol.size.width > 0 ? symbol.size : NSSize(width: 18, height: 18)

        guard active else {
            symbol.isTemplate = true
            return symbol
        }

        let tinted = NSImage(size: size)
        tinted.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        Theme.nsPink.set()
        rect.fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }
}
