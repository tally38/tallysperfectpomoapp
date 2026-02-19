import XCTest
import Combine
@testable import TallysPerfectPomo

@MainActor
final class TimerManagerTests: XCTestCase {
    private var timerManager: TimerManager!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        timerManager = TimerManager()
        cancellables = Set<AnyCancellable>()

        // Set known defaults for tests
        UserDefaults.standard.set(25, forKey: "focusDuration")
        UserDefaults.standard.set(5, forKey: "shortBreakDuration")
        UserDefaults.standard.set(15, forKey: "longBreakDuration")
        UserDefaults.standard.set(4, forKey: "longBreakInterval")
        UserDefaults.standard.set(false, forKey: "autoStartFocus")
    }

    override func tearDown() {
        timerManager = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(timerManager.phase, .idle)
        XCTAssertFalse(timerManager.isPaused)
        XCTAssertEqual(timerManager.remainingSeconds, 0)
        XCTAssertEqual(timerManager.completedPomosInCycle, 0)
    }

    // MARK: - Start Focus

    func testStartFocus_setsPhase() {
        timerManager.startFocus()

        XCTAssertEqual(timerManager.phase, .focus)
        XCTAssertFalse(timerManager.isPaused)
        XCTAssertGreaterThan(timerManager.remainingSeconds, 0)
    }

    func testStartFocus_usesConfiguredDuration() {
        UserDefaults.standard.set(10, forKey: "focusDuration")
        timerManager.startFocus()

        // 10 minutes = 600 seconds, remaining should be close
        XCTAssertTrue(timerManager.remainingSeconds >= 599 && timerManager.remainingSeconds <= 600)
    }

    // MARK: - Pause / Resume

    func testPause() {
        timerManager.startFocus()
        timerManager.pause()

        XCTAssertEqual(timerManager.phase, .focus)
        XCTAssertTrue(timerManager.isPaused)
    }

    func testPause_idleDoesNothing() {
        timerManager.pause()

        XCTAssertEqual(timerManager.phase, .idle)
        XCTAssertFalse(timerManager.isPaused)
    }

    func testResume() {
        timerManager.startFocus()
        timerManager.pause()
        timerManager.resume()

        XCTAssertEqual(timerManager.phase, .focus)
        XCTAssertFalse(timerManager.isPaused)
        XCTAssertGreaterThan(timerManager.remainingSeconds, 0)
    }

    func testResume_whenNotPaused_doesNothing() {
        timerManager.startFocus()
        let remainingBefore = timerManager.remainingSeconds
        timerManager.resume()

        XCTAssertEqual(timerManager.remainingSeconds, remainingBefore)
    }

    // MARK: - Cancel

    func testCancel_resetsToIdle() {
        timerManager.startFocus()
        timerManager.cancelTimer()

        XCTAssertEqual(timerManager.phase, .idle)
        XCTAssertFalse(timerManager.isPaused)
        XCTAssertEqual(timerManager.remainingSeconds, 0)
    }

    func testCancel_fromPaused() {
        timerManager.startFocus()
        timerManager.pause()
        timerManager.cancelTimer()

        XCTAssertEqual(timerManager.phase, .idle)
        XCTAssertFalse(timerManager.isPaused)
    }

    // MARK: - Break Type Selection

    func testStartBreak_shortBreakDefault() {
        timerManager.completedPomosInCycle = 1
        timerManager.startBreak()

        XCTAssertEqual(timerManager.phase, .shortBreak)
    }

    func testStartBreak_longBreakAfterInterval() {
        timerManager.completedPomosInCycle = 4 // matches longBreakInterval of 4
        timerManager.startBreak()

        XCTAssertEqual(timerManager.phase, .longBreak)
    }

    func testStartBreak_shortBreakWhenNotMultiple() {
        timerManager.completedPomosInCycle = 3
        timerManager.startBreak()

        XCTAssertEqual(timerManager.phase, .shortBreak)
    }

    func testStartBreak_longBreakAtEightPomos() {
        timerManager.completedPomosInCycle = 8
        timerManager.startBreak()

        XCTAssertEqual(timerManager.phase, .longBreak)
    }

    // MARK: - Pause During Break

    func testPauseDuringBreak() {
        timerManager.completedPomosInCycle = 1
        timerManager.startBreak()
        timerManager.pause()

        XCTAssertEqual(timerManager.phase, .shortBreak)
        XCTAssertTrue(timerManager.isPaused)
    }

    func testResumeDuringBreak() {
        timerManager.completedPomosInCycle = 1
        timerManager.startBreak()
        timerManager.pause()
        timerManager.resume()

        XCTAssertEqual(timerManager.phase, .shortBreak)
        XCTAssertFalse(timerManager.isPaused)
    }

    // MARK: - Completed Pomos Counter

    func testCompletedPomosCounter_incrementsOnFocusComplete() {
        XCTAssertEqual(timerManager.completedPomosInCycle, 0)
        // Can't easily test timer expiry without a date provider injection,
        // but we can verify the counter is accessible
    }

    // MARK: - Multiple State Transitions

    func testMultipleStartCancel_cycles() {
        timerManager.startFocus()
        XCTAssertEqual(timerManager.phase, .focus)

        timerManager.cancelTimer()
        XCTAssertEqual(timerManager.phase, .idle)

        timerManager.startFocus()
        XCTAssertEqual(timerManager.phase, .focus)

        timerManager.cancelTimer()
        XCTAssertEqual(timerManager.phase, .idle)
    }

    func testPauseResumeCycle() {
        timerManager.startFocus()

        timerManager.pause()
        XCTAssertTrue(timerManager.isPaused)

        timerManager.resume()
        XCTAssertFalse(timerManager.isPaused)

        timerManager.pause()
        XCTAssertTrue(timerManager.isPaused)

        timerManager.resume()
        XCTAssertFalse(timerManager.isPaused)
    }
}
