import Foundation

struct PomodoroEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    var duration: TimeInterval
    var notes: String
    let type: EntryType
    let manual: Bool

    enum EntryType: String, Codable {
        case focus
    }
}
