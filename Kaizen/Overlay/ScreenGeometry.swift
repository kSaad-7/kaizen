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
        widgetFrame(
            position: position,
            compact: size,
            expanded: size,
            isExpanded: false,
            on: screen,
            margin: margin
        )
    }

    /// Bottom of the panel stays put when expanding. Extra height grows upward.
    /// `compact` is used to pick the preferred bottom, then the bottom is clamped
    /// so `expanded` still fits in the visible frame.
    static func widgetFrame(
        position: TimerPosition,
        compact: CGSize,
        expanded: CGSize,
        isExpanded: Bool,
        on screen: NSScreen,
        margin: CGFloat = 16
    ) -> NSRect {
        let visible = screen.visibleFrame
        let size = isExpanded ? expanded : compact

        let preferredBottom: CGFloat
        if position.isTop {
            preferredBottom = visible.maxY - compact.height - margin
        } else {
            preferredBottom = visible.minY + margin
        }
        let maxBottom = visible.maxY - margin - expanded.height
        let minBottom = visible.minY + margin
        let bottom = min(max(preferredBottom, minBottom), maxBottom)

        let x: CGFloat
        switch position {
        case .topLeft, .bottomLeft:
            x = visible.minX + margin
        case .topCenter, .bottomCenter:
            x = visible.midX - size.width / 2
        case .topRight, .bottomRight:
            x = visible.maxX - size.width - margin
        }

        return NSRect(x: x, y: bottom, width: size.width, height: size.height)
    }
}
