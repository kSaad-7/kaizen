import AppKit
import Combine

@MainActor
final class OverlayCoordinator {
    private let sessionManager: SessionManager
    private let timerController: FloatingTimerController
    private var cancellables = Set<AnyCancellable>()
    private var screenObserver: NSObjectProtocol?
    private var completionStarted = false
    private var lastPosition: TimerPosition?
    private var lastHidden: Bool?

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self.timerController = FloatingTimerController(sessionManager: sessionManager)
    }

    func start() {
        sessionManager.$session
            .combineLatest(sessionManager.$preferences)
            .sink { [weak self] session, preferences in
                self?.sync(session: session, preferences: preferences)
            }
            .store(in: &cancellables)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.lastPosition = nil
                self.sync(session: self.sessionManager.session, preferences: self.sessionManager.preferences)
            }
        }

        sync(session: sessionManager.session, preferences: sessionManager.preferences)
    }

    private func sync(session: FocusSession?, preferences: Preferences) {
        guard let session else {
            completionStarted = false
            lastPosition = nil
            lastHidden = nil
            timerController.hide(animated: true)
            return
        }

        let wantTimer = !preferences.isTimerHidden || session.isCompleting
        if wantTimer {
            let needsShow = lastHidden != false
            let needsMove = lastPosition != preferences.timerPosition
            if needsShow || needsMove {
                timerController.ensureVisible(preferences: preferences)
            }
            lastHidden = false
            lastPosition = preferences.timerPosition
        } else {
            timerController.hide(animated: true)
            lastHidden = true
        }

        if session.isCompleting, !completionStarted {
            completionStarted = true
            if preferences.isTimerHidden {
                sessionManager.finishCompletion()
            } else {
                timerController.playCompletionThenDismiss { [weak self] in
                    self?.sessionManager.finishCompletion()
                }
            }
        }
    }
}
