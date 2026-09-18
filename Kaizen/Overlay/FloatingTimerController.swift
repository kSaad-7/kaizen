import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class TimerChrome: ObservableObject {
    @Published var isExpanded = false
    @Published var isFlashing = false
}

@MainActor
final class FloatingTimerController {
    private let sessionManager: SessionManager
    private let chrome = TimerChrome()
    private var panel: NSPanel?
    private var hosting: NSHostingView<FloatingTimerRoot>?
    private var completionTask: Task<Void, Never>?
    private var shrinkTask: Task<Void, Never>?
    private var windowExpanded = false
    private var isHovering = false
    private var isMenuHeld = false

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    func ensureVisible(preferences: Preferences) {
        if chrome.isFlashing { return }
        let created = panel == nil
        if created {
            createPanel()
        }
        applyFrame(preferences: preferences)
        guard let panel else { return }
        if created || panel.alphaValue < 0.99 {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            panel.displayIfNeeded()
            DispatchQueue.main.async { [weak panel] in
                guard let panel else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Theme.Motion.widgetFade
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    context.allowsImplicitAnimation = false
                    panel.animator().alphaValue = 1
                }
            }
        } else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
    }

    func hide(animated: Bool) {
        if completionTask != nil { return }
        completionTask?.cancel()
        completionTask = nil
        shrinkTask?.cancel()
        isHovering = false
        isMenuHeld = false
        chrome.isExpanded = false
        chrome.isFlashing = false
        windowExpanded = false
        guard let panel, panel.isVisible || animated else {
            tearDown()
            return
        }
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Theme.Motion.fade
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    self?.tearDown()
                }
            })
        } else {
            tearDown()
        }
    }

    func playCompletionThenDismiss(completion: @escaping () -> Void) {
        shrinkTask?.cancel()
        isHovering = false
        isMenuHeld = false
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            chrome.isFlashing = true
            chrome.isExpanded = false
        }
        windowExpanded = false
        applyFrame(preferences: sessionManager.preferences)
        completionTask?.cancel()
        completionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Theme.Motion.completionBurst))
            guard !Task.isCancelled else { return }
            if let panel {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = Theme.Motion.completionFade
                        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        panel.animator().alphaValue = 0
                    }, completionHandler: {
                        cont.resume()
                    })
                }
            }
            guard !Task.isCancelled else { return }
            tearDown()
            completion()
        }
    }

    private func tearDown() {
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
        chrome.isExpanded = false
        chrome.isFlashing = false
        windowExpanded = false
        isHovering = false
        isMenuHeld = false
        completionTask = nil
    }

    private func createPanel() {
        let root = FloatingTimerRoot(
            sessionManager: sessionManager,
            chrome: chrome,
            onHoverChange: { [weak self] hovering in
                self?.handleHoverIntent(hovering)
            },
            onHoldChange: { [weak self] held in
                self?.setMenuHeld(held)
            }
        )
        let seed = expandedSize()
        let container = NSView(frame: NSRect(origin: .zero, size: compactSize()))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: root)
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(origin: .zero, size: seed)
        container.addSubview(hostingView)

        let panel = TimerPanel(
            contentRect: NSRect(origin: .zero, size: seed),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 2)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = container
        self.panel = panel
        self.hosting = hostingView
    }

    private func handleHoverIntent(_ hovering: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.setHovering(hovering)
        }
    }

    private func setHovering(_ hovering: Bool) {
        isHovering = hovering
        syncExpanded()
    }

    private func setMenuHeld(_ held: Bool) {
        isMenuHeld = held
        syncExpanded()
    }

    private func syncExpanded() {
        guard sessionManager.session?.isCompleting != true else { return }
        let wantExpanded = isHovering || isMenuHeld
        if wantExpanded {
            shrinkTask?.cancel()
            if !windowExpanded {
                windowExpanded = true
                applyFrame(preferences: sessionManager.preferences)
            }
            if !chrome.isExpanded {
                chrome.isExpanded = true
            }
            return
        }

        if chrome.isExpanded {
            chrome.isExpanded = false
        }
        shrinkTask?.cancel()
        shrinkTask = Task { @MainActor in
            try? await Task.sleep(for: Theme.Motion.widgetShrinkDelay)
            guard !Task.isCancelled else { return }
            guard !self.isHovering, !self.isMenuHeld else { return }
            self.windowExpanded = false
            self.applyFrame(preferences: self.sessionManager.preferences)
        }
    }

    private func applyFrame(preferences: Preferences) {
        guard let panel, let hosting, let screen = ScreenGeometry.menuBarScreen else { return }
        let compact = compactSize()
        let expanded = expandedSize()
        let frame = ScreenGeometry.widgetFrame(
            position: preferences.timerPosition,
            compact: compact,
            expanded: expanded,
            isExpanded: windowExpanded,
            on: screen
        )
        panel.setFrame(frame, display: true)

        let clip = frame.size
        let x: CGFloat
        switch preferences.timerPosition {
        case .topLeft, .bottomLeft:
            x = 0
        case .topRight, .bottomRight:
            x = clip.width - expanded.width
        case .topCenter, .bottomCenter:
            x = (clip.width - expanded.width) / 2
        }
        hosting.frame = NSRect(x: x, y: 0, width: expanded.width, height: expanded.height)
    }

    private func compactSize() -> CGSize {
        Theme.compactTimerSize(
            clock: sessionManager.session?.remaining.kaizenClock
                ?? sessionManager.preferences.lastDuration.kaizenClock,
            paused: sessionManager.session?.isPaused == true
        )
    }

    private func expandedSize() -> CGSize {
        Theme.expandedTimerSize
    }
}

struct FloatingTimerRoot: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var chrome: TimerChrome
    var onHoverChange: (Bool) -> Void
    var onHoldChange: (Bool) -> Void

    var body: some View {
        FloatingTimerView(onHoverChange: onHoverChange, onHoldChange: onHoldChange)
            .environmentObject(sessionManager)
            .environmentObject(chrome)
    }
}

private final class TimerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
