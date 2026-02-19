import XCTest
@testable import TallysPerfectPomo

final class PomodoroStoreTests: XCTestCase {
    private var tempDir: URL!
    private var tempFileURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempFileURL = tempDir.appendingPathComponent("test_pomo_log.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeEntry(
        notes: String = "",
        startedAt: Date = Date(),
        duration: TimeInterval = 1500,
        manual: Bool = false
    ) -> PomodoroEntry {
        PomodoroEntry(
            id: UUID(),
            startedAt: startedAt,
            duration: duration,
            notes: notes,
            type: .focus,
            manual: manual
        )
    }

    // MARK: - CRUD

    func testAddEntry() {
        let store = PomodoroStore(fileURL: tempFileURL)
        let entry = makeEntry(notes: "Test entry")

        store.addEntry(entry)

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.notes, "Test entry")
    }

    func testAddMultipleEntries_sortedByDate() {
        let store = PomodoroStore(fileURL: tempFileURL)
        let older = makeEntry(notes: "Older", startedAt: Date().addingTimeInterval(-3600))
        let newer = makeEntry(notes: "Newer", startedAt: Date())

        store.addEntry(older)
        store.addEntry(newer)

        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries.first?.notes, "Newer")
        XCTAssertEqual(store.entries.last?.notes, "Older")
    }

    func testUpdateNotes() {
        let store = PomodoroStore(fileURL: tempFileURL)
        let entry = makeEntry(notes: "Original")
        store.addEntry(entry)

        store.updateNotes(id: entry.id, notes: "Updated")

        XCTAssertEqual(store.entries.first?.notes, "Updated")
    }

    func testUpdateNotes_nonexistentId() {
        let store = PomodoroStore(fileURL: tempFileURL)
        let entry = makeEntry(notes: "Original")
        store.addEntry(entry)

        store.updateNotes(id: UUID(), notes: "Should not work")

        XCTAssertEqual(store.entries.first?.notes, "Original")
    }

    func testDeleteEntry() {
        let store = PomodoroStore(fileURL: tempFileURL)
        let entry = makeEntry(notes: "To delete")
        store.addEntry(entry)

        store.deleteEntry(id: entry.id)

        XCTAssertTrue(store.entries.isEmpty)
    }

    func testDeleteEntry_nonexistentId() {
        let store = PomodoroStore(fileURL: tempFileURL)
        let entry = makeEntry(notes: "Keep")
        store.addEntry(entry)

        store.deleteEntry(id: UUID())

        XCTAssertEqual(store.entries.count, 1)
    }

    // MARK: - Persistence

    func testPersistenceAcrossInstances() {
        let store1 = PomodoroStore(fileURL: tempFileURL)
        store1.addEntry(makeEntry(notes: "Persisted"))

        let store2 = PomodoroStore(fileURL: tempFileURL)

        XCTAssertEqual(store2.entries.count, 1)
        XCTAssertEqual(store2.entries.first?.notes, "Persisted")
    }

    func testCorruptedJSON_returnsEmpty() {
        // Write garbage JSON to the file
        try? "{ not valid json [[[".data(using: .utf8)?.write(to: tempFileURL)

        let store = PomodoroStore(fileURL: tempFileURL)

        XCTAssertTrue(store.entries.isEmpty)
    }

    func testEmptyFile_returnsEmpty() {
        try? Data().write(to: tempFileURL)

        let store = PomodoroStore(fileURL: tempFileURL)

        XCTAssertTrue(store.entries.isEmpty)
    }

    func testNoFile_returnsEmpty() {
        let store = PomodoroStore(fileURL: tempFileURL)

        XCTAssertTrue(store.entries.isEmpty)
    }

    // MARK: - Grouping

    func testEntriesGroupedByDay() {
        let store = PomodoroStore(fileURL: tempFileURL)
        let today1 = makeEntry(notes: "Today 1", startedAt: Date())
        let today2 = makeEntry(notes: "Today 2", startedAt: Date().addingTimeInterval(-60))
        let yesterday = makeEntry(
            notes: "Yesterday",
            startedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        )

        store.addEntry(today1)
        store.addEntry(today2)
        store.addEntry(yesterday)

        let groups = store.entriesGroupedByDay()

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.label, "Today")
        XCTAssertEqual(groups.first?.entries.count, 2)
        XCTAssertEqual(groups.last?.label, "Yesterday")
        XCTAssertEqual(groups.last?.entries.count, 1)
    }

    func testTodayCount() {
        let store = PomodoroStore(fileURL: tempFileURL)
        store.addEntry(makeEntry(notes: "Today"))
        store.addEntry(makeEntry(
            notes: "Yesterday",
            startedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ))

        XCTAssertEqual(store.todayCount(), 1)
    }

    // MARK: - Manual entry

    func testManualEntry() {
        let store = PomodoroStore(fileURL: tempFileURL)
        let entry = makeEntry(notes: "Manual", manual: true)
        store.addEntry(entry)

        XCTAssertTrue(store.entries.first?.manual ?? false)
    }
}
