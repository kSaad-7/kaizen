import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class TimerChrome: ObservableObject {
    @Published var isExpanded = false
}

@MainActor
final class FloatingTimerController {
    private let sessionManager: SessionManager
    private let chrome = TimerChrome()
    private var panel: NSPanel?
    private var hosting: NSHostingView<FloatingTimerRoot>?
    private var completionTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var windowExpanded = false

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    func ensureVisible(preferences: Preferences) {
        let created = panel == nil
        if created {
            createPanel()
        }
        applyFrame(preferences: preferences)
        guard let panel else { return }
        if created || panel.alphaValue < 0.99 {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Theme.Motion.fade
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
    }

    func hide(animated: Bool) {
        completionTask?.cancel()
        completionTask = nil
        collapseTask?.cancel()
        chrome.isExpanded = false
        windowExpanded = false
        guard let panel, panel.isVisible || animated else {
            tearDown()
            return
        }
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Theme.Motion.fade
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
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
        chrome.isExpanded = false
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
                        context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
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
        windowExpanded = false
    }

    private func createPanel() {
        let root = FloatingTimerRoot(
            sessionManager: sessionManager,
            chrome: chrome,
            onHoverChange: { [weak self] hovering in
                self?.handleHoverIntent(hovering)
            }
        )
        let seed = Theme.compactTimerSize(clock: "00:00", paused: false)
        let container = NSView(frame: NSRect(origin: .zero, size: seed))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let hostingView = NSHostingView(rootView: root)
        hostingView.sizingOptions = []
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
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
            self?.applyHover(hovering)
        }
    }

    private func applyHover(_ hovering: Bool) {
        guard sessionManager.session?.isCompleting != true else { return }
        collapseTask?.cancel()
        if hovering {
            windowExpanded = true
            applyFrame(preferences: sessionManager.preferences)
            withAnimation(Theme.Motion.hoverEnterAnimation) {
                chrome.isExpanded = true
            }
            return
        }
        collapseTask = Task { @MainActor in
            try? await Task.sleep(for: Theme.Motion.hoverDelay)
            guard !Task.isCancelled else { return }
            withAnimation(Theme.Motion.hoverExitAnimation) {
                chrome.isExpanded = false
            }
            try? await Task.sleep(for: Theme.Motion.hoverExit)
            guard !Task.isCancelled else { return }
            windowExpanded = false
            applyFrame(preferences: sessionManager.preferences)
        }
    }

    private func applyFrame(preferences: Preferences) {
        guard let panel, let screen = ScreenGeometry.menuBarScreen else { return }
        let size = windowExpanded ? expandedSize() : compactSize()
        let frame = ScreenGeometry.frame(for: preferences.timerPosition, size: size, on: screen)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        hosting?.frame = NSRect(origin: .zero, size: size)
    }

    private func compactSize() -> CGSize {
        Theme.compactTimerSize(
            clock: sessionManager.session?.remaining.kaizenClock ?? "00:00",
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

    var body: some View {
        FloatingTimerView(onHoverChange: onHoverChange)
            .environmentObject(sessionManager)
            .environmentObject(chrome)
    }
}

private final class TimerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
