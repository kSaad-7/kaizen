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
            view.imageAlignment = .alignTopLeft
            view.wantsLayer = true
            view.layer?.magnificationFilter = .nearest
            view.layer?.minificationFilter = .nearest
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
        let widthPx = max(1, Int((bounds.width * scale).rounded()))
        let heightPx = max(1, Int((bounds.height * scale).rounded()))
        let thicknessPx = Int((Double(min(widthPx, heightPx)) * 0.11).rounded())
        guard thicknessPx > 8, widthPx > thicknessPx * 2, heightPx > thicknessPx * 2 else { return }

        let innerW = widthPx - thicknessPx * 2
        let innerH = heightPx - thicknessPx * 2

        func place(_ piece: DitherRenderer.Piece, x: Int, y: Int, w: Int, h: Int) {
            guard let view = pieces.first(where: { $0.0 == piece })?.1 else { return }
            let pointSize = CGSize(width: CGFloat(w) / scale, height: CGFloat(h) / scale)
            view.image = DitherRenderer.image(
                piece: piece,
                pixelSize: (w, h),
                pointSize: pointSize,
                pixelOrigin: (x, y)
            )
            // y is pixels from the top of the screen. Views use a bottom-left origin.
            view.frame = NSRect(
                x: CGFloat(x) / scale,
                y: CGFloat(heightPx - (y + h)) / scale,
                width: pointSize.width,
                height: pointSize.height
            )
        }

        place(.corner(.topLeft), x: 0, y: 0, w: thicknessPx, h: thicknessPx)
        place(.edge(.top), x: thicknessPx, y: 0, w: innerW, h: thicknessPx)
        place(.corner(.topRight), x: widthPx - thicknessPx, y: 0, w: thicknessPx, h: thicknessPx)

        place(.edge(.left), x: 0, y: thicknessPx, w: thicknessPx, h: innerH)
        place(.edge(.right), x: widthPx - thicknessPx, y: thicknessPx, w: thicknessPx, h: innerH)

        place(.corner(.bottomLeft), x: 0, y: heightPx - thicknessPx, w: thicknessPx, h: thicknessPx)
        place(.edge(.bottom), x: thicknessPx, y: heightPx - thicknessPx, w: innerW, h: thicknessPx)
        place(.corner(.bottomRight), x: widthPx - thicknessPx, y: heightPx - thicknessPx, w: thicknessPx, h: thicknessPx)
    }
}
