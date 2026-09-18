import AppKit
import Foundation

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var session: FocusSession?
    @Published private(set) var checklist: [ChecklistItem] = []
    @Published private(set) var preferences: Preferences = .default
    @Published var isDebugShortTimers = false

    private let store = PersistenceStore()
    private var timer: DispatchSourceTimer?
    private var wakeObserver: NSObjectProtocol?

    init() {
        checklist = store.loadChecklist()
        preferences = store.loadPreferences()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncFromWallClock()
            }
        }
    }

    var hasActiveSession: Bool { session != nil }
    var isRunning: Bool { session?.isRunning == true }
    var sessionItems: [ChecklistItem] { session?.items ?? [] }

    func startSession(name: String, duration: TimeInterval, items: [ChecklistItem] = []) {
        guard session == nil else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let resolved: TimeInterval
        if isDebugShortTimers {
            resolved = 5
        } else {
            resolved = DurationLimits.clamp(duration)
            setLastDuration(resolved)
        }
        session = FocusSession(
            name: trimmed,
            totalDuration: resolved,
            remaining: resolved,
            state: .running,
            items: items,
            deadline: Date().addingTimeInterval(resolved)
        )
        startTimer()
    }

    func pause() {
        guard var session, session.isRunning else { return }
        syncRemaining(&session)
        session.state = .paused
        session.deadline = nil
        self.session = session
        stopTimer()
    }

    func resume() {
        guard var session, session.isPaused else { return }
        session.state = .running
        session.deadline = Date().addingTimeInterval(max(0, session.remaining))
        self.session = session
        startTimer()
    }

    func stop() {
        stopTimer()
        mergeIncompleteIntoPersistent()
        session = nil
    }

    func beginCompletion() {
        guard var session, session.state != .completing else { return }
        session.remaining = 0
        session.state = .completing
        session.deadline = nil
        self.session = session
        stopTimer()
        SoundPlayer.playCompletionIfPresent()
    }

    func finishCompletion() {
        guard session?.isCompleting == true else { return }
        mergeIncompleteIntoPersistent()
        session = nil
    }

    func setTimerHidden(_ hidden: Bool) {
        preferences.isTimerHidden = hidden
        store.savePreferences(preferences)
    }

    func setTimerPosition(_ position: TimerPosition) {
        preferences.timerPosition = position
        store.savePreferences(preferences)
    }

    func setLastDuration(_ duration: TimeInterval) {
        preferences.lastDuration = DurationLimits.clamp(duration)
        store.savePreferences(preferences)
    }

    @discardableResult
    func addPersistentItem(_ text: String) -> ChecklistItem? {
        guard let item = makeItem(text) else { return nil }
        checklist.append(item)
        store.saveChecklist(checklist)
        return item
    }

    func togglePersistentItem(_ id: UUID) {
        guard let index = checklist.firstIndex(where: { $0.id == id }) else { return }
        checklist[index].isChecked.toggle()
        store.saveChecklist(checklist)
    }

    func deletePersistentItem(_ id: UUID) {
        checklist.removeAll { $0.id == id }
        store.saveChecklist(checklist)
    }

    @discardableResult
    func addSessionItem(_ text: String) -> ChecklistItem? {
        guard var session, let item = makeItem(text) else { return nil }
        session.items.append(item)
        self.session = session
        return item
    }

    func toggleSessionItem(_ id: UUID) {
        guard var session, let index = session.items.firstIndex(where: { $0.id == id }) else { return }
        session.items[index].isChecked.toggle()
        self.session = session
    }

    func deleteSessionItem(_ id: UUID) {
        guard var session else { return }
        session.items.removeAll { $0.id == id }
        self.session = session
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func syncFromWallClock() {
        guard var session, session.isRunning else { return }
        syncRemaining(&session)
        self.session = session
        if session.remaining <= 0 {
            beginCompletion()
        }
    }

    private func makeItem(_ text: String) -> ChecklistItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return ChecklistItem(text: trimmed)
    }

    private func mergeIncompleteIntoPersistent() {
        guard let session else { return }
        let leftovers = session.items.filter { !$0.isChecked }
        guard !leftovers.isEmpty else { return }
        let existing = Set(checklist.filter { !$0.isChecked }.map(\.text))
        for item in leftovers where !existing.contains(item.text) {
            checklist.append(item)
        }
        store.saveChecklist(checklist)
    }

    private func startTimer() {
        stopTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        self.timer = timer
    }

    private func stopTimer() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        guard var session, session.isRunning else { return }
        syncRemaining(&session)
        self.session = session
        if session.remaining <= 0 {
            beginCompletion()
        }
    }

    private func syncRemaining(_ session: inout FocusSession) {
        guard let deadline = session.deadline else { return }
        session.remaining = max(0, deadline.timeIntervalSinceNow)
    }
}
