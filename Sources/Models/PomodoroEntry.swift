import Foundation

struct PomodoroEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    var duration: TimeInterval
    var notes: String
    var type: EntryType
    let manual: Bool

    struct EntryType: RawRepresentable, Codable, Equatable, Hashable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        static let focus = EntryType(rawValue: "focus")
        static let meeting = EntryType(rawValue: "meeting")
    }
}
