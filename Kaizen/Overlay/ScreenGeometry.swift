import AppKit

enum ScreenGeometry {
    static var menuBarScreen: NSScreen? {
        NSScreen.screens.first
    }

    static func frame(
        for position: TimerPosition,
        size: CGSize,
        on screen: NSScreen,
        margin: CGFloat = 16
    ) -> NSRect {
        let visible = screen.visibleFrame
        let x: CGFloat
        let y: CGFloat
        switch position {
        case .topLeft:
            x = visible.minX + margin
            y = visible.maxY - size.height - margin
        case .topCenter:
            x = visible.midX - size.width / 2
            y = visible.maxY - size.height - margin
        case .topRight:
            x = visible.maxX - size.width - margin
            y = visible.maxY - size.height - margin
        case .bottomLeft:
            x = visible.minX + margin
            y = visible.minY + margin
        case .bottomCenter:
            x = visible.midX - size.width / 2
            y = visible.minY + margin
        case .bottomRight:
            x = visible.maxX - size.width - margin
            y = visible.minY + margin
        }
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
