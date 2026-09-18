import SwiftUI

struct FloatingTimerView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var chrome: TimerChrome
    var onHoverChange: (Bool) -> Void
    var onHoldChange: (Bool) -> Void

    private var menuVisible: Bool {
        chrome.isExpanded && sessionManager.session?.isCompleting != true
    }

    private var completing: Bool {
        sessionManager.session?.isCompleting == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.widgetGap) {
            menuBlock
                .opacity(menuVisible ? 1 : 0)
                .animation(chrome.isFlashing ? nil : Theme.Motion.widgetFadeAnimation, value: menuVisible)
                .allowsHitTesting(menuVisible)

            timerRow
        }
        .frame(width: Theme.expandedTimerSize.width, height: Theme.expandedTimerSize.height, alignment: .bottomLeading)
        .preferredColorScheme(.dark)
        .onHover(perform: onHoverChange)
        .onChange(of: completing) { _, nowCompleting in
            if nowCompleting {
                onHoldChange(false)
            }
        }
    }

    private var paused: Bool {
        sessionManager.session?.isPaused == true
    }

    private var clockLabel: String {
        if let remaining = sessionManager.session?.remaining {
            return remaining.kaizenClock
        }
        return sessionManager.preferences.lastDuration.kaizenClock
    }

    private var timerRow: some View {
        HStack(spacing: 0) {
            if !sessionManager.preferences.timerPosition.isLeading {
                Spacer(minLength: 0)
            }
            timerCard
            if !sessionManager.preferences.timerPosition.isTrailing {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var menuBlock: some View {
        VStack(alignment: .leading, spacing: Theme.widgetGap) {
            if let session = sessionManager.session {
                checklistCard(session)
            }
            HStack(spacing: 0) {
                if !sessionManager.preferences.timerPosition.isLeading {
                    Spacer(minLength: 0)
                }
                actionCard
                if !sessionManager.preferences.timerPosition.isTrailing {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var timerCard: some View {
        HStack(spacing: 6) {
            TimerGlyph(size: 12)
                .foregroundStyle(paused ? Theme.muted : Theme.text)
            Text(clockLabel)
                .font(Theme.Typeface.timer())
                .monospacedDigit()
                .foregroundStyle(paused ? Theme.muted : Theme.text)
                .contentTransition(.identity)
                .transaction { $0.animation = nil }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            KaizenSurface(cornerRadius: Theme.radiusS)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                .fill(Theme.pink.opacity(chrome.isFlashing ? 0.55 : 0))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                .strokeBorder(chrome.isFlashing ? Theme.pink : Theme.stroke, lineWidth: 1)
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
                systemName: "stop.fill",
                help: "Stop"
            ) {
                sessionManager.beginCompletion()
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
            onDelete: { sessionManager.deleteSessionItem($0) },
            onFocusChange: onHoldChange
        )
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .top)
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
