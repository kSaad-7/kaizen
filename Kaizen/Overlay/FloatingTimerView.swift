import SwiftUI

struct FloatingTimerView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var chrome: TimerChrome
    var onHoverChange: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var closeArmed = false
    @State private var armTask: Task<Void, Never>?
    @State private var flash = false

    private var showChrome: Bool {
        chrome.isExpanded && sessionManager.session?.isCompleting != true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                timerCard
                if showChrome {
                    actionCard
                        .transition(chromeTransition(anchor: .leading))
                }
            }
            if showChrome, let session = sessionManager.session, !session.isCompleting {
                checklistCard(session)
                    .transition(chromeTransition(anchor: .top))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .preferredColorScheme(.dark)
        .onHover(perform: onHoverChange)
        .onChange(of: sessionManager.session?.state) { _, state in
            if state == .completing {
                closeArmed = false
                withAnimation(Theme.Motion.hoverEnterAnimation) { flash = true }
                withAnimation(Theme.Motion.fadeAnimation.delay(0.4)) { flash = false }
            } else {
                flash = false
            }
        }
        .onChange(of: chrome.isExpanded) { _, expanded in
            if !expanded {
                closeArmed = false
            }
        }
        .onDisappear {
            armTask?.cancel()
        }
    }

    private func chromeTransition(anchor: UnitPoint) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: anchor)),
            removal: .opacity
        )
    }

    private var paused: Bool {
        sessionManager.session?.isPaused == true
    }

    private var timerCard: some View {
        HStack(spacing: 6) {
            TimerGlyph(size: 12)
                .foregroundStyle(paused ? Theme.muted : Theme.text)
            Text(sessionManager.session?.remaining.kaizenClock ?? "00:00")
                .font(Theme.Typeface.timer())
                .monospacedDigit()
                .foregroundStyle(paused ? Theme.muted : Theme.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            KaizenSurface(cornerRadius: Theme.radiusS)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                .strokeBorder(flash ? Theme.pink : Theme.stroke, lineWidth: 1)
        }
        .overlay {
            if sessionManager.session?.isCompleting == true {
                RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                    .fill(Theme.pink.opacity(flash ? 0.28 : 0))
            }
        }
    }

    private var actionCard: some View {
        HStack(spacing: 2) {
            SessionIconButton(
                systemName: paused ? "play.fill" : "pause.fill",
                help: paused ? "Resume" : "Pause"
            ) {
                if paused {
                    sessionManager.resume()
                } else {
                    sessionManager.pause()
                }
            }

            SessionIconButton(
                systemName: closeArmed ? "checkmark" : "stop.fill",
                help: closeArmed ? "Confirm stop" : "Stop",
                tint: closeArmed ? Theme.pink : Theme.text
            ) {
                if closeArmed {
                    sessionManager.stop()
                } else {
                    closeArmed = true
                    armTask?.cancel()
                    armTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(Theme.Motion.closeArmTimeout))
                        guard !Task.isCancelled else { return }
                        closeArmed = false
                    }
                }
            }
        }
        .padding(4)
        .background {
            KaizenSurface(cornerRadius: Theme.radiusS)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private func checklistCard(_ session: FocusSession) -> some View {
        ChecklistList(
            items: session.items,
            addPrompt: "Add a task",
            itemListHeight: Theme.hoverChecklistListHeight,
            onAdd: { sessionManager.addSessionItem($0) },
            onToggle: { sessionManager.toggleSessionItem($0) },
            onDelete: { sessionManager.deleteSessionItem($0) }
        )
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            KaizenSurface(cornerRadius: Theme.radiusS)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
