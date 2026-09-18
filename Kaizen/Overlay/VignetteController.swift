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
                (window.contentView as? VignetteView)?.layoutFrame()
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
    private let pieces: [(DitherRenderer.Piece, NSImageView)] = {
        let kinds: [DitherRenderer.Piece] = [
            .edge(.top), .edge(.bottom), .edge(.left), .edge(.right),
            .corner(.topLeft), .corner(.topRight), .corner(.bottomLeft), .corner(.bottomRight)
        ]
        return kinds.map { piece in
            let view = NSImageView()
            view.imageScaling = .scaleAxesIndependently
            return (piece, view)
        }
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        for (_, view) in pieces {
            addSubview(view)
        }
        layoutFrame()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutFrame()
    }

    func layoutFrame() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let thickness = min(bounds.width, bounds.height) * 0.28
        guard thickness > 8, bounds.width > thickness * 2, bounds.height > thickness * 2 else { return }

        let width = bounds.width
        let height = bounds.height
        let innerWidth = width - thickness * 2
        let innerHeight = height - thickness * 2

        func place(_ piece: DitherRenderer.Piece, frame: NSRect) {
            guard let view = pieces.first(where: { $0.0 == piece })?.1 else { return }
            view.image = DitherRenderer.image(piece: piece, pointSize: frame.size, scale: scale)
            view.frame = frame
        }

        place(.corner(.bottomLeft), frame: NSRect(x: 0, y: 0, width: thickness, height: thickness))
        place(.edge(.bottom), frame: NSRect(x: thickness, y: 0, width: innerWidth, height: thickness))
        place(.corner(.bottomRight), frame: NSRect(x: width - thickness, y: 0, width: thickness, height: thickness))

        place(.edge(.left), frame: NSRect(x: 0, y: thickness, width: thickness, height: innerHeight))
        place(.edge(.right), frame: NSRect(x: width - thickness, y: thickness, width: thickness, height: innerHeight))

        place(.corner(.topLeft), frame: NSRect(x: 0, y: height - thickness, width: thickness, height: thickness))
        place(.edge(.top), frame: NSRect(x: thickness, y: height - thickness, width: innerWidth, height: thickness))
        place(.corner(.topRight), frame: NSRect(x: width - thickness, y: height - thickness, width: thickness, height: thickness))
    }
}
