import XCTest
@testable import TallysPerfectPomo

final class AnalyticsTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a PomodoroEntry at the given date with the given duration in minutes.
    private func makeEntry(
        at date: Date,
        durationMinutes: Double = 25,
        type: PomodoroEntry.EntryType = .focus
    ) -> PomodoroEntry {
        PomodoroEntry(
            id: UUID(),
            startedAt: date,
            duration: durationMinutes * 60,
            notes: "",
            type: type,
            manual: false
        )
    }

    /// Returns a Date for the given "yyyy-MM-dd HH:mm" string.
    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = Calendar.current.timeZone
        return formatter.date(from: string)!
    }

    // MARK: - weekRange

    func testWeekRange_currentWeek_startsOnMonday() {
        // Wednesday Feb 19, 2026
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)

        let calendar = Calendar.current
        let startWeekday = calendar.component(.weekday, from: range.start)
        XCTAssertEqual(startWeekday, 2, "Week should start on Monday (weekday 2)")

        // Start should be Monday Feb 16
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)
        XCTAssertEqual(startComponents.year, 2026)
        XCTAssertEqual(startComponents.month, 2)
        XCTAssertEqual(startComponents.day, 16)
    }

    func testWeekRange_currentWeek_endsOnSunday() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)

        let calendar = Calendar.current
        let endComponents = calendar.dateComponents([.year, .month, .day], from: range.end)
        XCTAssertEqual(endComponents.month, 2)
        XCTAssertEqual(endComponents.day, 22)
    }

    func testWeekRange_previousWeek() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: -1, referenceDate: ref)

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)
        XCTAssertEqual(startComponents.month, 2)
        XCTAssertEqual(startComponents.day, 9, "Previous week Monday should be Feb 9")
    }

    func testWeekRange_onMonday() {
        // Monday Feb 16, 2026
        let ref = date("2026-02-16 08:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.day], from: range.start)
        XCTAssertEqual(startComponents.day, 16, "On Monday, week should start on same day")
    }

    func testWeekRange_onSunday() {
        // Sunday Feb 22, 2026
        let ref = date("2026-02-22 20:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.day], from: range.start)
        XCTAssertEqual(startComponents.day, 16, "On Sunday, week should still start on Monday the 16th")
    }

    // MARK: - aggregate

    func testAggregate_emptyEntries_returns7Days() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)
        let result = AnalyticsCalculator.aggregate(entries: [], in: range)

        // Should have 7 days * 1 type (focus default) = 7 items
        XCTAssertEqual(result.count, 7)

        // All should have 0 minutes
        for item in result {
            XCTAssertEqual(item.totalMinutes, 0, accuracy: 0.01)
        }
    }

    func testAggregate_singleEntry() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)

        // Feb 18 = Wednesday (dayIndex 2)
        let entries = [makeEntry(at: date("2026-02-18 10:00"), durationMinutes: 25)]
        let result = AnalyticsCalculator.aggregate(entries: entries, in: range)

        let wedFocus = result.first { $0.dayIndex == 2 && $0.typeRawValue == "focus" }
        XCTAssertNotNil(wedFocus)
        XCTAssertEqual(wedFocus?.totalMinutes ?? 0, 25, accuracy: 0.01)
    }

    func testAggregate_multipleTypes() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)

        let entries = [
            makeEntry(at: date("2026-02-18 10:00"), durationMinutes: 25, type: .focus),
            makeEntry(at: date("2026-02-18 11:00"), durationMinutes: 30, type: .meeting),
        ]
        let result = AnalyticsCalculator.aggregate(entries: entries, in: range)

        // Should have 7 days * 2 types = 14 items
        XCTAssertEqual(result.count, 14)

        // Feb 18 = Wednesday (dayIndex 2)
        let wedFocus = result.first { $0.dayIndex == 2 && $0.typeRawValue == "focus" }
        let wedMeeting = result.first { $0.dayIndex == 2 && $0.typeRawValue == "meeting" }
        XCTAssertEqual(wedFocus?.totalMinutes ?? 0, 25, accuracy: 0.01)
        XCTAssertEqual(wedMeeting?.totalMinutes ?? 0, 30, accuracy: 0.01)
    }

    func testAggregate_entriesOutsideRange_excluded() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)

        let entries = [
            makeEntry(at: date("2026-02-10 10:00"), durationMinutes: 25),  // previous week
            makeEntry(at: date("2026-02-18 10:00"), durationMinutes: 30),  // this week
        ]
        let result = AnalyticsCalculator.aggregate(entries: entries, in: range)

        let totalMinutes = result.reduce(0.0) { $0 + $1.totalMinutes }
        XCTAssertEqual(totalMinutes, 30, accuracy: 0.01, "Only this week's entry should be included")
    }

    func testAggregate_multipleSameDay_sums() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)

        let entries = [
            makeEntry(at: date("2026-02-18 09:00"), durationMinutes: 25),
            makeEntry(at: date("2026-02-18 10:00"), durationMinutes: 25),
            makeEntry(at: date("2026-02-18 14:00"), durationMinutes: 25),
        ]
        let result = AnalyticsCalculator.aggregate(entries: entries, in: range)

        // Feb 18 = Wednesday (dayIndex 2)
        let wedFocus = result.first { $0.dayIndex == 2 && $0.typeRawValue == "focus" }
        XCTAssertEqual(wedFocus?.totalMinutes ?? 0, 75, accuracy: 0.01)
    }

    func testAggregate_dayLabelsAreMonToSun() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)
        let result = AnalyticsCalculator.aggregate(entries: [], in: range)

        let labels = result.sorted { $0.dayIndex < $1.dayIndex }.map(\.dayLabel)
        let expected = AnalyticsCalculator.mondayBasedDayLabels()
        XCTAssertEqual(labels, expected)
    }

    // MARK: - dailyAverage

    func testDailyAverage_fullPastWeek_dividesBySeven() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: -1, referenceDate: ref)

        // 7 entries of 25 min each = 175 total / 7 = 25 avg
        var entries: [PomodoroEntry] = []
        for day in 9...15 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 25))
        }
        let avg = AnalyticsCalculator.dailyAverage(entries: entries, in: range, referenceDate: ref)
        XCTAssertEqual(avg, 25, accuracy: 0.01)
    }

    func testDailyAverage_currentWeek_dividesByElapsedDays() {
        // Reference: Wednesday Feb 19 => elapsed = Mon, Tue, Wed = 3 days
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)

        // 75 min total over the week so far → 75/3 = 25 avg
        let entries = [
            makeEntry(at: date("2026-02-16 10:00"), durationMinutes: 25), // Mon
            makeEntry(at: date("2026-02-17 10:00"), durationMinutes: 25), // Tue
            makeEntry(at: date("2026-02-18 10:00"), durationMinutes: 25), // Wed (day before ref)
        ]
        let avg = AnalyticsCalculator.dailyAverage(entries: entries, in: range, referenceDate: ref)
        // Elapsed days: Mon(16) to Wed(19) = 4 days
        // 75 / 4 = 18.75
        XCTAssertEqual(avg, 75.0 / 4.0, accuracy: 0.01)
    }

    func testDailyAverage_noEntries_returnsZero() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: -1, referenceDate: ref)
        let avg = AnalyticsCalculator.dailyAverage(entries: [], in: range, referenceDate: ref)
        XCTAssertEqual(avg, 0, accuracy: 0.01)
    }

    // MARK: - weekSummary

    func testWeekSummary_noPriorData() {
        let ref = date("2026-02-19 12:00")
        let entries = [makeEntry(at: date("2026-02-18 10:00"), durationMinutes: 50)]

        let summary = AnalyticsCalculator.weekSummary(entries: entries, weekOffset: 0, referenceDate: ref)
        XCTAssertTrue(summary.dailyAverageMinutes > 0)
        XCTAssertNil(summary.previousWeekDailyAverage)
        XCTAssertNil(summary.percentChange)
    }

    func testWeekSummary_withPriorData_increase() {
        let ref = date("2026-02-19 12:00")
        var entries: [PomodoroEntry] = []

        // Last week: 7 * 20 min = 140 total, avg = 20
        for day in 9...15 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 20))
        }

        // This week (Mon–Thu elapsed = 4 days): 4 * 30 = 120 total, avg = 30
        for day in 16...19 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 30))
        }

        let summary = AnalyticsCalculator.weekSummary(entries: entries, weekOffset: 0, referenceDate: ref)
        XCTAssertEqual(summary.dailyAverageMinutes, 30, accuracy: 0.01)
        XCTAssertEqual(summary.previousWeekDailyAverage ?? 0, 20, accuracy: 0.01)
        XCTAssertEqual(summary.percentChange ?? 0, 50, accuracy: 0.01)  // 50% increase
    }

    func testWeekSummary_withPriorData_decrease() {
        let ref = date("2026-02-19 12:00")
        var entries: [PomodoroEntry] = []

        // Last week: 7 * 40 min avg
        for day in 9...15 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 40))
        }

        // This week: 4 * 20 min avg
        for day in 16...19 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 20))
        }

        let summary = AnalyticsCalculator.weekSummary(entries: entries, weekOffset: 0, referenceDate: ref)
        XCTAssertEqual(summary.percentChange ?? 0, -50, accuracy: 0.01)  // 50% decrease
    }

    // MARK: - totalMinutes

    func testTotalMinutes_allDays() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)
        let entries = [
            makeEntry(at: date("2026-02-16 10:00"), durationMinutes: 25), // Mon
            makeEntry(at: date("2026-02-17 10:00"), durationMinutes: 30), // Tue
            makeEntry(at: date("2026-02-21 10:00"), durationMinutes: 20), // Sat
        ]
        let total = AnalyticsCalculator.totalMinutes(entries: entries, in: range)
        XCTAssertEqual(total, 75, accuracy: 0.01)
    }

    func testTotalMinutes_weekdaysOnly() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)
        let entries = [
            makeEntry(at: date("2026-02-16 10:00"), durationMinutes: 25), // Mon
            makeEntry(at: date("2026-02-17 10:00"), durationMinutes: 30), // Tue
            makeEntry(at: date("2026-02-21 10:00"), durationMinutes: 20), // Sat
            makeEntry(at: date("2026-02-22 10:00"), durationMinutes: 15), // Sun
        ]
        let total = AnalyticsCalculator.totalMinutes(entries: entries, in: range, weekdaysOnly: true)
        XCTAssertEqual(total, 55, accuracy: 0.01, "Should only include Mon + Tue, not Sat/Sun")
    }

    func testTotalMinutes_withTypeFilter() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)
        let entries = [
            makeEntry(at: date("2026-02-16 10:00"), durationMinutes: 25, type: .focus),
            makeEntry(at: date("2026-02-17 10:00"), durationMinutes: 30, type: .meeting),
        ]
        let total = AnalyticsCalculator.totalMinutes(entries: entries, in: range, typeFilter: [.focus])
        XCTAssertEqual(total, 25, accuracy: 0.01, "Should only include focus entries")
    }

    func testTotalMinutes_weekdaysOnly_withTypeFilter() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)
        let entries = [
            makeEntry(at: date("2026-02-16 10:00"), durationMinutes: 25, type: .focus),   // Mon
            makeEntry(at: date("2026-02-16 11:00"), durationMinutes: 30, type: .meeting),  // Mon
            makeEntry(at: date("2026-02-21 10:00"), durationMinutes: 20, type: .focus),    // Sat
        ]
        let total = AnalyticsCalculator.totalMinutes(entries: entries, in: range, weekdaysOnly: true, typeFilter: [.focus])
        XCTAssertEqual(total, 25, accuracy: 0.01, "Mon focus only; excludes Mon meeting and Sat focus")
    }

    func testTotalMinutes_emptyEntries() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)
        let total = AnalyticsCalculator.totalMinutes(entries: [], in: range)
        XCTAssertEqual(total, 0, accuracy: 0.01)
    }

    // MARK: - weekdayDailyAverage

    func testWeekdayDailyAverage_fullPastWeek() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: -1, referenceDate: ref)
        // Feb 9 (Mon) through Feb 13 (Fri) = 5 weekdays, each 30 min = 150 total
        var entries: [PomodoroEntry] = []
        for day in 9...13 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 30))
        }
        // Sat/Sun entries should be excluded
        entries.append(makeEntry(at: date("2026-02-14 10:00"), durationMinutes: 50))
        entries.append(makeEntry(at: date("2026-02-15 10:00"), durationMinutes: 50))

        let avg = AnalyticsCalculator.weekdayDailyAverage(entries: entries, in: range, referenceDate: ref)
        // 150 / 5 = 30
        XCTAssertEqual(avg, 30, accuracy: 0.01)
    }

    func testWeekdayDailyAverage_currentWeek_partialWeekdays() {
        // Wednesday Feb 19 => elapsed weekdays: Mon(16), Tue(17), Wed(18), Thu(19) = 4 weekdays
        // Wait: Feb 16=Mon, 17=Tue, 18=Wed, 19=Thu
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)
        let entries = [
            makeEntry(at: date("2026-02-16 10:00"), durationMinutes: 20), // Mon
            makeEntry(at: date("2026-02-17 10:00"), durationMinutes: 20), // Tue
        ]
        let avg = AnalyticsCalculator.weekdayDailyAverage(entries: entries, in: range, referenceDate: ref)
        // 40 min / 4 elapsed weekdays = 10
        XCTAssertEqual(avg, 10, accuracy: 0.01)
    }

    func testWeekdayDailyAverage_withTypeFilter() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: -1, referenceDate: ref)
        var entries: [PomodoroEntry] = []
        for day in 9...13 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 30, type: .focus))
            entries.append(makeEntry(at: date("2026-02-\(day) 11:00"), durationMinutes: 10, type: .meeting))
        }
        let avg = AnalyticsCalculator.weekdayDailyAverage(entries: entries, in: range, referenceDate: ref, typeFilter: [.focus])
        // 150 / 5 = 30 (only focus)
        XCTAssertEqual(avg, 30, accuracy: 0.01)
    }

    func testWeekdayDailyAverage_noEntries() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: -1, referenceDate: ref)
        let avg = AnalyticsCalculator.weekdayDailyAverage(entries: [], in: range, referenceDate: ref)
        XCTAssertEqual(avg, 0, accuracy: 0.01)
    }

    // MARK: - todayVsRecent

    func testTodayVsRecent_basicComparison() {
        let ref = date("2026-02-19 12:00") // Wednesday
        var entries: [PomodoroEntry] = []
        // Past 7 days: Feb 12-18, each 20 min = 140 total, avg = 20
        for day in 12...18 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 20))
        }
        // Today: 30 min
        entries.append(makeEntry(at: date("2026-02-19 09:00"), durationMinutes: 30))

        let result = AnalyticsCalculator.todayVsRecent(entries: entries, referenceDate: ref)
        XCTAssertEqual(result.todayMinutes, 30, accuracy: 0.01)
        XCTAssertEqual(result.recentDailyAverage, 20, accuracy: 0.01)
        XCTAssertEqual(result.percentChange ?? 0, 50, accuracy: 0.01)
    }

    func testTodayVsRecent_noRecentData() {
        let ref = date("2026-02-19 12:00")
        let entries = [makeEntry(at: date("2026-02-19 09:00"), durationMinutes: 25)]

        let result = AnalyticsCalculator.todayVsRecent(entries: entries, referenceDate: ref)
        XCTAssertEqual(result.todayMinutes, 25, accuracy: 0.01)
        XCTAssertEqual(result.recentDailyAverage, 0, accuracy: 0.01)
        XCTAssertNil(result.percentChange)
    }

    func testTodayVsRecent_withTypeFilter() {
        let ref = date("2026-02-19 12:00")
        var entries: [PomodoroEntry] = []
        for day in 12...18 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 20, type: .focus))
            entries.append(makeEntry(at: date("2026-02-\(day) 11:00"), durationMinutes: 10, type: .meeting))
        }
        entries.append(makeEntry(at: date("2026-02-19 09:00"), durationMinutes: 25, type: .focus))
        entries.append(makeEntry(at: date("2026-02-19 10:00"), durationMinutes: 15, type: .meeting))

        let result = AnalyticsCalculator.todayVsRecent(entries: entries, referenceDate: ref, typeFilter: [.focus])
        XCTAssertEqual(result.todayMinutes, 25, accuracy: 0.01, "Only today's focus")
        XCTAssertEqual(result.recentDailyAverage, 20, accuracy: 0.01, "Only past focus avg")
    }

    func testTodayVsRecent_noTodayData() {
        let ref = date("2026-02-19 12:00")
        var entries: [PomodoroEntry] = []
        for day in 12...18 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 20))
        }

        let result = AnalyticsCalculator.todayVsRecent(entries: entries, referenceDate: ref)
        XCTAssertEqual(result.todayMinutes, 0, accuracy: 0.01)
        XCTAssertEqual(result.recentDailyAverage, 20, accuracy: 0.01)
    }

    // MARK: - Type filtering on existing methods

    func testAggregate_withTypeFilter() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: 0, referenceDate: ref)
        let entries = [
            makeEntry(at: date("2026-02-18 10:00"), durationMinutes: 25, type: .focus),
            makeEntry(at: date("2026-02-18 11:00"), durationMinutes: 30, type: .meeting),
        ]
        let result = AnalyticsCalculator.aggregate(entries: entries, in: range, typeFilter: [.focus])

        let types = Set(result.map(\.typeRawValue))
        XCTAssertEqual(types, ["focus"])

        // Feb 18 = Wednesday (dayIndex 2)
        let wedFocus = result.first { $0.dayIndex == 2 && $0.typeRawValue == "focus" }
        XCTAssertEqual(wedFocus?.totalMinutes ?? 0, 25, accuracy: 0.01)
    }

    func testDailyAverage_withTypeFilter() {
        let ref = date("2026-02-19 12:00")
        let range = AnalyticsCalculator.weekRange(offset: -1, referenceDate: ref)
        var entries: [PomodoroEntry] = []
        for day in 9...15 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 25, type: .focus))
            entries.append(makeEntry(at: date("2026-02-\(day) 11:00"), durationMinutes: 15, type: .meeting))
        }
        let avg = AnalyticsCalculator.dailyAverage(entries: entries, in: range, referenceDate: ref, typeFilter: [.focus])
        XCTAssertEqual(avg, 25, accuracy: 0.01, "Should only average focus entries")
    }

    func testWeekSummary_withTypeFilter() {
        let ref = date("2026-02-19 12:00")
        var entries: [PomodoroEntry] = []
        // Last week: focus 20/day, meeting 10/day
        for day in 9...15 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 20, type: .focus))
            entries.append(makeEntry(at: date("2026-02-\(day) 11:00"), durationMinutes: 10, type: .meeting))
        }
        // This week: focus 30/day
        for day in 16...19 {
            entries.append(makeEntry(at: date("2026-02-\(day) 10:00"), durationMinutes: 30, type: .focus))
        }
        let summary = AnalyticsCalculator.weekSummary(entries: entries, weekOffset: 0, referenceDate: ref, typeFilter: [.focus])
        XCTAssertEqual(summary.dailyAverageMinutes, 30, accuracy: 0.01)
        XCTAssertEqual(summary.previousWeekDailyAverage ?? 0, 20, accuracy: 0.01, "Prior week focus only")
        XCTAssertEqual(summary.percentChange ?? 0, 50, accuracy: 0.01)
    }

    // MARK: - mondayBasedDayLabels

    func testMondayBasedDayLabels_startsWithMon() {
        let labels = AnalyticsCalculator.mondayBasedDayLabels()
        XCTAssertEqual(labels.count, 7)
        XCTAssertEqual(labels.first, "Mon")
        XCTAssertEqual(labels.last, "Sun")
    }

    // MARK: - formatMediumDate

    func testFormatMediumDate() {
        let d = date("2026-02-16 00:00")
        let result = Formatters.formatMediumDate(d)
        XCTAssertEqual(result, "Feb 16, 2026")
    }
}
