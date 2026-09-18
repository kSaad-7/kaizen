import Foundation

enum SessionState: String, Codable {
    case running
    case paused
    case completing
}

struct FocusSession: Equatable {
    var name: String
    var totalDuration: TimeInterval
    var remaining: TimeInterval
    var state: SessionState
    var items: [ChecklistItem]
    var deadline: Date?

    var elapsedFraction: Double {
        guard totalDuration > 0 else { return 1 }
        return min(1, max(0, 1 - remaining / totalDuration))
    }

    var isRunning: Bool { state == .running }
    var isPaused: Bool { state == .paused }
    var isCompleting: Bool { state == .completing }
}

struct ChecklistItem: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var text: String
    var isChecked: Bool
    var createdAt: Date

    init(id: UUID = UUID(), text: String, isChecked: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
        self.createdAt = createdAt
    }
}

enum TimerPosition: String, Codable, CaseIterable, Identifiable {
    case topLeft, topCenter, topRight
    case bottomLeft, bottomCenter, bottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft: "Top Left"
        case .topCenter: "Top Center"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomCenter: "Bottom Center"
        case .bottomRight: "Bottom Right"
        }
    }

    var isTop: Bool {
        switch self {
        case .topLeft, .topCenter, .topRight: true
        case .bottomLeft, .bottomCenter, .bottomRight: false
        }
    }

    var isLeading: Bool {
        switch self {
        case .topLeft, .bottomLeft: true
        default: false
        }
    }

    var isTrailing: Bool {
        switch self {
        case .topRight, .bottomRight: true
        default: false
        }
    }
}

struct Preferences: Codable, Equatable {
    var timerPosition: TimerPosition
    var isTimerHidden: Bool
    var lastDuration: TimeInterval

    static let `default` = Preferences(
        timerPosition: .bottomCenter,
        isTimerHidden: false,
        lastDuration: 30 * 60
    )
}

enum DurationLimits {
    static let minimum: TimeInterval = 60
    static let maximum: TimeInterval = 8 * 60 * 60

    static let presets: [(label: String, seconds: TimeInterval)] = [
        ("10m", 10 * 60),
        ("30m", 30 * 60),
        ("1h", 60 * 60),
        ("2h", 2 * 60 * 60)
    ]

    static func clamp(_ value: TimeInterval) -> TimeInterval {
        min(maximum, max(minimum, value))
    }
}

extension TimeInterval {
    var kaizenClock: String {
        let total = max(0, Int(ceil(self - 0.000_001)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
