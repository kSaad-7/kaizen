import SwiftUI

struct PillSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0 { value = next }
    }
}

struct FloatingTimerView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var chrome: TimerChrome
    var onHoverChange: (Bool) -> Void
    var onHoldChange: (Bool) -> Void
    var onPillSize: (CGSize) -> Void

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
        .frame(width: panelWidth, height: Theme.expandedTimerSize.height, alignment: .bottomLeading)
        .preferredColorScheme(.dark)
        .onHover(perform: onHoverChange)
        .onPreferenceChange(PillSizeKey.self, perform: onPillSize)
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

    private var sessionName: String {
        sessionManager.session?.name ?? ""
    }

    private var pendingCount: Int {
        sessionManager.session?.items.filter { !$0.isChecked }.count ?? 0
    }

    private var panelWidth: CGFloat {
        Theme.expandedTimerWidth(name: sessionName, clock: clockLabel, pending: pendingCount)
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
            sessionNameLabel
            Text("-")
                .font(.system(size: Theme.widgetTimerSize, weight: .medium))
                .foregroundStyle(paused ? Theme.muted : Theme.text)
                .fixedSize()
            Text(clockLabel)
                .font(.system(size: Theme.widgetTimerSize, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(paused ? Theme.muted : Theme.text)
                .lineLimit(1)
                .frame(width: Theme.widgetClockWidth(clockLabel), alignment: .center)
                .contentTransition(.identity)
                .transaction { $0.animation = nil }
            pendingMark
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
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
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: PillSizeKey.self, value: geo.size)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var sessionNameLabel: some View {
        let text = Text(sessionName)
            .font(.system(size: Theme.widgetTimerSize, weight: .medium))
            .foregroundStyle(paused ? Theme.muted : Theme.text)
            .lineLimit(1)
            .truncationMode(.tail)
        let width = Theme.widgetNameWidth(sessionName)
        return Group {
            if width >= Theme.widgetNameMaxWidth {
                text.frame(width: Theme.widgetNameMaxWidth, alignment: .leading)
            } else {
                text.fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var pendingMark: some View {
        HStack(spacing: 3) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 9, weight: .medium))
            Text("\(pendingCount)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .frame(width: Theme.widgetCountWidth(pendingCount), alignment: .leading)
        }
        .foregroundStyle(Color.white.opacity(0.72))
        .padding(.leading, 2)
        .fixedSize()
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
