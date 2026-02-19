import Foundation

class PomodoroStore: ObservableObject {
    @Published var entries: [PomodoroEntry] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDir = appSupport.appendingPathComponent("TallysPerfectPomo", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        self.fileURL = appDir.appendingPathComponent("pomo_log.json")
        self.entries = loadEntries()
    }

    /// For testing: allow injecting a custom file URL
    init(fileURL: URL) {
        self.fileURL = fileURL
        self.entries = loadEntries()
    }

    // MARK: - CRUD

    func addEntry(_ entry: PomodoroEntry) {
        entries.append(entry)
        entries.sort { $0.startedAt > $1.startedAt }
        save()
    }

    func updateNotes(id: UUID, notes: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].notes = notes
        save()
    }

    func updateType(id: UUID, type: PomodoroEntry.EntryType) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].type = type
        save()
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    // MARK: - Grouped Access

    struct DayGroup: Identifiable {
        let id: String
        let label: String
        let entries: [PomodoroEntry]
    }

    func entriesGroupedByDay() -> [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.startedAt)
        }

        return grouped
            .sorted { $0.key > $1.key }
            .map { (day, dayEntries) in
                DayGroup(
                    id: day.ISO8601Format(),
                    label: Formatters.formatRelativeDay(day),
                    entries: dayEntries.sorted { $0.startedAt > $1.startedAt }
                )
            }
    }

    func todayCount() -> Int {
        let calendar = Calendar.current
        return entries.filter { calendar.isDateInToday($0.startedAt) }.count
    }

    // MARK: - Persistence

    private func loadEntries() -> [PomodoroEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([PomodoroEntry].self, from: data)
        } catch {
            // Corrupted JSON: log and return empty
            print("PomodoroStore: failed to load entries: \(error). Starting fresh.")
            return []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entries)

            // Atomic write: write to temp file, then replace
            let tempURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent(UUID().uuidString + ".tmp")
            try data.write(to: tempURL, options: .atomic)

            // Replace the original file atomically
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } catch {
            print("PomodoroStore: failed to save entries: \(error)")
        }
    }
}
