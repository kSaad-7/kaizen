import SwiftUI

enum MenuRoute {
    case home
    case start
    case checklist
}

struct MenuBarRootView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var route: MenuRoute = .home

    var body: some View {
        Group {
            switch route {
            case .home:
                home
            case .start:
                StartSessionView(onBack: { route = .home })
            case .checklist:
                checklistScreen
            }
        }
        .padding(12)
        .frame(width: route == .checklist ? Theme.checklistMenuWidth : Theme.menuWidth)
        .frame(minHeight: route == .checklist ? Theme.checklistMenuMinHeight : nil, alignment: .top)
        .background(KaizenSurface())
        .preferredColorScheme(.dark)
        .tint(Theme.pink)
        .background(MenuBarWindowConfigurator())
        .onChange(of: sessionManager.hasActiveSession) { _, active in
            if active { route = .home }
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let session = sessionManager.session {
                activeHeader(session)
            } else {
                idleHeader
            }

            Divider().overlay(Theme.hairline)

            navRow(title: "Checklist", detail: checklistCount) {
                route = .checklist
            }

            #if DEBUG
            Toggle(isOn: debugTimersBinding) {
                Text("Debug 5s timers")
                    .font(Theme.Typeface.body())
                    .foregroundStyle(Theme.muted)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            #endif

            Button("Quit") { sessionManager.quit() }
                .buttonStyle(KaizenButtonStyle(kind: .plain))
                .foregroundStyle(Theme.muted)
        }
    }

    private var idleHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kaizen")
                .font(Theme.Typeface.micro())
                .foregroundStyle(Theme.muted)
            Button {
                route = .start
            } label: {
                HStack(spacing: 6) {
                    TimerGlyph(size: 12)
                    Text("Start session")
                }
            }
            .buttonStyle(KaizenButtonStyle(kind: .primary))
        }
    }

    private func activeHeader(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.name)
                .font(Theme.Typeface.title())
                .foregroundStyle(Theme.text)
                .lineLimit(1)

            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    TimerGlyph(size: 13)
                        .foregroundStyle(session.isPaused ? Theme.muted : Theme.text)
                    Text(session.remaining.kaizenClock)
                        .font(Theme.Typeface.timer())
                        .monospacedDigit()
                        .foregroundStyle(session.isPaused ? Theme.muted : Theme.text)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.fill)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }

                HStack(spacing: 2) {
                    SessionIconButton(
                        systemName: session.isPaused ? "play.fill" : "pause.fill",
                        help: session.isPaused ? "Resume" : "Pause"
                    ) {
                        if session.isPaused { sessionManager.resume() } else { sessionManager.pause() }
                    }
                    SessionIconButton(
                        systemName: "stop.fill",
                        help: "Stop"
                    ) {
                        sessionManager.stop()
                    }
                }
                .padding(4)
                .background(Theme.fill)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }

                Spacer(minLength: 0)
            }

            Divider().overlay(Theme.hairline)

            PositionPicker(
                selection: sessionManager.preferences.timerPosition,
                onSelect: { sessionManager.setTimerPosition($0) }
            )

            Toggle(isOn: hideBinding) {
                Text("Hide timer")
                    .font(Theme.Typeface.body())
                    .foregroundStyle(Theme.text)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
    }

    private var checklistScreen: some View {
        VStack(alignment: .leading, spacing: 8) {
            BackButton { route = .home }

            Text("Checklist")
                .font(Theme.Typeface.title())
                .foregroundStyle(Theme.text)

            ChecklistList(
                items: sessionManager.checklist,
                itemListMaxHeight: 340,
                onAdd: { sessionManager.addPersistentItem($0) },
                onToggle: { sessionManager.togglePersistentItem($0) },
                onDelete: { sessionManager.deletePersistentItem($0) }
            )
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var checklistCount: String? {
        let count = sessionManager.checklist.filter { !$0.isChecked }.count
        return count == 0 ? nil : "\(count)"
    }

    #if DEBUG
    private var debugTimersBinding: Binding<Bool> {
        Binding(
            get: { sessionManager.isDebugShortTimers },
            set: { sessionManager.isDebugShortTimers = $0 }
        )
    }
    #endif

    private var hideBinding: Binding<Bool> {
        Binding(
            get: { sessionManager.preferences.isTimerHidden },
            set: { sessionManager.setTimerHidden($0) }
        )
    }

    private func navRow(title: String, detail: String?, action: @escaping () -> Void) -> some View {
        MenuNavRow(title: title, detail: detail, action: action)
    }
}

private struct MenuNavRow: View {
    var title: String
    var detail: String?
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Theme.Typeface.body())
                    .foregroundStyle(Theme.text)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(Theme.Typeface.caption())
                        .foregroundStyle(Theme.muted)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(hovering ? Theme.pink : Theme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.fadeAnimation, value: hovering)
    }
}

private struct MenuBarWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(nsView.window)
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.backgroundColor = Theme.nsBackground
        window.isOpaque = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.appearance = NSAppearance(named: .darkAqua)
    }
}
