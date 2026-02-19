import XCTest
@testable import TallysPerfectPomo

final class FormattersTests: XCTestCase {

    // MARK: - formatCountdown

    func testFormatCountdown_zeroSeconds() {
        XCTAssertEqual(Formatters.formatCountdown(0), "0:00")
    }

    func testFormatCountdown_underOneMinute() {
        XCTAssertEqual(Formatters.formatCountdown(5), "0:05")
        XCTAssertEqual(Formatters.formatCountdown(59), "0:59")
    }

    func testFormatCountdown_exactMinutes() {
        XCTAssertEqual(Formatters.formatCountdown(60), "1:00")
        XCTAssertEqual(Formatters.formatCountdown(300), "5:00")
        XCTAssertEqual(Formatters.formatCountdown(1500), "25:00")
    }

    func testFormatCountdown_minutesAndSeconds() {
        XCTAssertEqual(Formatters.formatCountdown(1421), "23:41")
        XCTAssertEqual(Formatters.formatCountdown(61), "1:01")
        XCTAssertEqual(Formatters.formatCountdown(3599), "59:59")
    }

    func testFormatCountdown_overOneHour() {
        XCTAssertEqual(Formatters.formatCountdown(3600), "60:00")
        XCTAssertEqual(Formatters.formatCountdown(3661), "61:01")
    }

    // MARK: - formatRelativeDay

    func testFormatRelativeDay_today() {
        XCTAssertEqual(Formatters.formatRelativeDay(Date()), "Today")
    }

    func testFormatRelativeDay_yesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertEqual(Formatters.formatRelativeDay(yesterday), "Yesterday")
    }

    func testFormatRelativeDay_olderDate() {
        var components = DateComponents()
        components.year = 2025
        components.month = 2
        components.day = 17
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(Formatters.formatRelativeDay(date), "Feb 17, 2025")
    }

    // MARK: - formatTime

    func testFormatTime_afternoon() {
        var components = DateComponents()
        components.year = 2025
        components.month = 2
        components.day = 19
        components.hour = 14
        components.minute = 30
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(Formatters.formatTime(date), "2:30 PM")
    }

    func testFormatTime_morning() {
        var components = DateComponents()
        components.year = 2025
        components.month = 2
        components.day = 19
        components.hour = 9
        components.minute = 5
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(Formatters.formatTime(date), "9:05 AM")
    }

    // MARK: - formatDuration

    func testFormatDuration_zeroSeconds() {
        XCTAssertEqual(Formatters.formatDuration(0), "0 sec")
    }

    func testFormatDuration_underOneMinute() {
        XCTAssertEqual(Formatters.formatDuration(45), "45 sec")
    }

    func testFormatDuration_exactMinutes() {
        XCTAssertEqual(Formatters.formatDuration(1500), "25 min")
        XCTAssertEqual(Formatters.formatDuration(300), "5 min")
        XCTAssertEqual(Formatters.formatDuration(900), "15 min")
    }

    func testFormatDuration_oneMinute() {
        XCTAssertEqual(Formatters.formatDuration(60), "1 min")
    }
}
