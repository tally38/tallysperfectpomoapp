import Foundation

enum TimerPhase: String, Codable, Equatable {
    case idle
    case focus
    case shortBreak
    case longBreak
}

enum TimerEvent {
    case focusCompleted(startedAt: Date, duration: TimeInterval, type: PomodoroEntry.EntryType)
    case breakCompleted
}
