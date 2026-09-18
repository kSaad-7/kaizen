import AppKit

@MainActor
final class VignetteController {
    private var windows: [NSNumber: NSWindow] = [:]
    private var lastRunning: Bool?

    func sync(isRunning: Bool) {
        if lastRunning == isRunning { return }
        lastRunning = isRunning
        rebuildIfNeeded()
        applyVisibility(isRunning)
    }

    func screensChanged() {
        lastRunning = nil
        rebuildIfNeeded()
    }

    private func rebuildIfNeeded() {
        let screens = NSScreen.screens
        var seen = Set<NSNumber>()
        for screen in screens {
            let key = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
                ?? NSNumber(value: ObjectIdentifier(screen).hashValue)
            seen.insert(key)
            if let window = windows[key] {
                window.setFrame(screen.frame, display: true)
                (window.contentView as? VignetteView)?.layoutCorners()
            } else {
                windows[key] = makeWindow(for: screen)
            }
        }
        for key in windows.keys where !seen.contains(key) {
            windows[key]?.orderOut(nil)
            windows.removeValue(forKey: key)
        }
    }

    private func applyVisibility(_ isRunning: Bool) {
        for window in windows.values {
            if isRunning {
                if !window.isVisible {
                    window.alphaValue = 0
                    window.orderFrontRegardless()
                }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Theme.Motion.vignette
                    window.animator().alphaValue = 1
                }
            } else if window.isVisible || window.alphaValue > 0.01 {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = Theme.Motion.vignette
                    window.animator().alphaValue = 0
                }, completionHandler: {
                    Task { @MainActor in
                        if window.alphaValue < 0.02 {
                            window.orderOut(nil)
                        }
                    }
                })
            }
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.animationBehavior = .none
        window.alphaValue = 0
        window.contentView = VignetteView(frame: NSRect(origin: .zero, size: screen.frame.size))
        return window
    }
}

@MainActor
private final class VignetteView: NSView {
    private let cornerViews: [DitherRenderer.Corner: NSImageView] = {
        var views: [DitherRenderer.Corner: NSImageView] = [:]
        for corner in [DitherRenderer.Corner.topLeft, .topRight, .bottomLeft, .bottomRight] {
            let view = NSImageView()
            view.imageScaling = .scaleAxesIndependently
            views[corner] = view
        }
        return views
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        for view in cornerViews.values {
            addSubview(view)
        }
        layoutCorners()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutCorners()
    }

    func layoutCorners() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let size = min(bounds.width, bounds.height) * 0.52
        guard size > 8 else { return }

        func place(_ corner: DitherRenderer.Corner, x: CGFloat, y: CGFloat) {
            guard let view = cornerViews[corner] else { return }
            view.image = DitherRenderer.cornerImage(corner: corner, pointSize: size, scale: scale)
            view.frame = NSRect(x: x, y: y, width: size, height: size)
        }

        place(.topLeft, x: 0, y: bounds.maxY - size)
        place(.topRight, x: bounds.maxX - size, y: bounds.maxY - size)
        place(.bottomLeft, x: 0, y: 0)
        place(.bottomRight, x: bounds.maxX - size, y: 0)
    }
}
