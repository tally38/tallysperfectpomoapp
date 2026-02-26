import Foundation

enum AnalyticsCalculator {

    struct DayTypeAggregate: Identifiable, Equatable {
        var id: String { "\(dayIndex)-\(typeRawValue)" }
        let dayIndex: Int       // 0 = Mon, 6 = Sun
        let dayLabel: String    // "Mon", "Tue", ...
        let date: Date          // start of that calendar day
        let typeRawValue: String
        let totalMinutes: Double
    }

    struct WeekSummary: Equatable {
        let dailyAverageMinutes: Double
        let previousWeekDailyAverage: Double?
        let percentChange: Double?
    }

    struct TodayComparison: Equatable {
        let todayMinutes: Double
        let recentDailyAverage: Double  // avg of prior 7 calendar days
        let percentChange: Double?      // nil if recentDailyAverage is 0
    }

    // MARK: - Week Range

    /// Returns (Monday 00:00, Sunday 23:59:59) for the week at the given offset.
    /// offset 0 = current week, -1 = last week, etc.
    static func weekRange(offset: Int, referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        // calendar weekday: 1=Sun, 2=Mon, ..., 7=Sat
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7  // Mon=0, Tue=1, ... Sun=6
        let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let targetMonday = calendar.date(byAdding: .weekOfYear, value: offset, to: thisMonday)!
        let targetSunday = calendar.date(byAdding: .day, value: 6, to: targetMonday)!
        let endOfSunday = calendar.date(byAdding: .second, value: 86399, to: targetSunday)!
        return (targetMonday, endOfSunday)
    }

    // MARK: - Filtering

    /// Filters entries by date range and optional type set.
    private static func filterEntries(
        _ entries: [PomodoroEntry],
        in range: (start: Date, end: Date),
        typeFilter: Set<PomodoroEntry.EntryType>?
    ) -> [PomodoroEntry] {
        entries.filter { entry in
            entry.startedAt >= range.start
            && entry.startedAt <= range.end
            && (typeFilter == nil || typeFilter!.contains(entry.type))
        }
    }

    // MARK: - Aggregation

    /// Aggregates entries within the given range into per-day, per-type totals.
    /// Always returns entries for all 7 days (Mon–Sun), with 0 minutes for empty days.
    static func aggregate(
        entries: [PomodoroEntry],
        in range: (start: Date, end: Date),
        typeFilter: Set<PomodoroEntry.EntryType>? = nil
    ) -> [DayTypeAggregate] {
        let calendar = Calendar.current
        let weekEntries = filterEntries(entries, in: range, typeFilter: typeFilter)

        // Build day labels for Mon–Sun of this week
        let dayLabels = mondayBasedDayLabels()

        // Accumulate minutes per (dayIndex, typeRawValue)
        var buckets: [String: Double] = [:]
        var typesInData: Set<String> = []

        for entry in weekEntries {
            let weekday = calendar.component(.weekday, from: entry.startedAt)
            let dayIndex = (weekday + 5) % 7  // Mon=0 ... Sun=6
            let key = "\(dayIndex)-\(entry.type.rawValue)"
            buckets[key, default: 0] += entry.duration / 60.0
            typesInData.insert(entry.type.rawValue)
        }

        // If no entries at all, use "focus" as the single type so the chart renders
        if typesInData.isEmpty {
            typesInData.insert(PomodoroEntry.EntryType.focus.rawValue)
        }

        // Build aggregates for all 7 days x all types present
        var results: [DayTypeAggregate] = []
        for dayIndex in 0..<7 {
            let dayDate = calendar.date(byAdding: .day, value: dayIndex, to: range.start)!
            for typeRaw in typesInData.sorted() {
                let key = "\(dayIndex)-\(typeRaw)"
                results.append(DayTypeAggregate(
                    dayIndex: dayIndex,
                    dayLabel: dayLabels[dayIndex],
                    date: dayDate,
                    typeRawValue: typeRaw,
                    totalMinutes: buckets[key] ?? 0
                ))
            }
        }

        return results
    }

    // MARK: - Daily Average

    /// Computes the daily average in minutes for entries in the given week range.
    /// For the current week (range containing referenceDate), divides by elapsed days.
    /// For past weeks, divides by 7.
    static func dailyAverage(
        entries: [PomodoroEntry],
        in range: (start: Date, end: Date),
        referenceDate: Date = Date(),
        typeFilter: Set<PomodoroEntry.EntryType>? = nil
    ) -> Double {
        let calendar = Calendar.current
        let weekEntries = filterEntries(entries, in: range, typeFilter: typeFilter)
        let totalMinutes = weekEntries.reduce(0.0) { $0 + $1.duration / 60.0 }

        let today = calendar.startOfDay(for: referenceDate)
        let daysElapsed: Int
        if today >= range.start && today <= range.end {
            // Current week: count days from Monday through today
            daysElapsed = max(1, (calendar.dateComponents([.day], from: range.start, to: today).day ?? 0) + 1)
        } else {
            daysElapsed = 7
        }

        return totalMinutes / Double(daysElapsed)
    }

    // MARK: - Week Summary

    /// Computes daily average for the given week offset and comparison to the prior week.
    static func weekSummary(
        entries: [PomodoroEntry],
        weekOffset: Int,
        referenceDate: Date = Date(),
        typeFilter: Set<PomodoroEntry.EntryType>? = nil
    ) -> WeekSummary {
        let currentRange = weekRange(offset: weekOffset, referenceDate: referenceDate)
        let currentAvg = dailyAverage(entries: entries, in: currentRange, referenceDate: referenceDate, typeFilter: typeFilter)

        let priorRange = weekRange(offset: weekOffset - 1, referenceDate: referenceDate)
        let priorEntries = filterEntries(entries, in: priorRange, typeFilter: typeFilter)

        if priorEntries.isEmpty {
            return WeekSummary(
                dailyAverageMinutes: currentAvg,
                previousWeekDailyAverage: nil,
                percentChange: nil
            )
        }

        let priorAvg = dailyAverage(entries: entries, in: priorRange, referenceDate: referenceDate, typeFilter: typeFilter)
        let pctChange: Double? = priorAvg > 0 ? ((currentAvg - priorAvg) / priorAvg) * 100 : nil

        return WeekSummary(
            dailyAverageMinutes: currentAvg,
            previousWeekDailyAverage: priorAvg,
            percentChange: pctChange
        )
    }

    // MARK: - Total Minutes

    /// Total minutes in the given range, optionally restricted to weekdays (Mon–Fri).
    static func totalMinutes(
        entries: [PomodoroEntry],
        in range: (start: Date, end: Date),
        weekdaysOnly: Bool = false,
        typeFilter: Set<PomodoroEntry.EntryType>? = nil
    ) -> Double {
        let calendar = Calendar.current
        let filtered = filterEntries(entries, in: range, typeFilter: typeFilter)
        return filtered
            .filter { entry in
                if weekdaysOnly {
                    let weekday = calendar.component(.weekday, from: entry.startedAt)
                    return weekday >= 2 && weekday <= 6  // Mon=2 ... Fri=6
                }
                return true
            }
            .reduce(0.0) { $0 + $1.duration / 60.0 }
    }

    // MARK: - Weekday Daily Average

    /// Computes the daily average in minutes for weekdays (Mon–Fri) only.
    /// For the current week, divides by elapsed weekdays. For past weeks, divides by 5.
    static func weekdayDailyAverage(
        entries: [PomodoroEntry],
        in range: (start: Date, end: Date),
        referenceDate: Date = Date(),
        typeFilter: Set<PomodoroEntry.EntryType>? = nil
    ) -> Double {
        let calendar = Calendar.current
        let weekdayMinutes = totalMinutes(entries: entries, in: range, weekdaysOnly: true, typeFilter: typeFilter)

        let today = calendar.startOfDay(for: referenceDate)
        let elapsedWeekdays: Int
        if today >= range.start && today <= range.end {
            var count = 0
            var day = range.start
            while day <= today {
                let wd = calendar.component(.weekday, from: day)
                if wd >= 2 && wd <= 6 { count += 1 }
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
            elapsedWeekdays = max(1, count)
        } else {
            elapsedWeekdays = 5
        }

        return weekdayMinutes / Double(elapsedWeekdays)
    }

    // MARK: - Today vs Recent

    /// Compares today's total to the daily average of the prior 7 calendar days.
    static func todayVsRecent(
        entries: [PomodoroEntry],
        referenceDate: Date = Date(),
        typeFilter: Set<PomodoroEntry.EntryType>? = nil
    ) -> TodayComparison {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: referenceDate)
        let todayEnd = calendar.date(byAdding: .second, value: 86399, to: todayStart)!

        let todayTotal = totalMinutes(
            entries: entries,
            in: (todayStart, todayEnd),
            typeFilter: typeFilter
        )

        let past7Start = calendar.date(byAdding: .day, value: -7, to: todayStart)!
        let past7End = calendar.date(byAdding: .second, value: -1, to: todayStart)!
        let past7Total = totalMinutes(
            entries: entries,
            in: (past7Start, past7End),
            typeFilter: typeFilter
        )
        let recentAvg = past7Total / 7.0

        let pctChange: Double? = recentAvg > 0
            ? ((todayTotal - recentAvg) / recentAvg) * 100
            : nil

        return TodayComparison(
            todayMinutes: todayTotal,
            recentDailyAverage: recentAvg,
            percentChange: pctChange
        )
    }

    // MARK: - Helpers

    /// Returns ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static func mondayBasedDayLabels() -> [String] {
        let symbols = Calendar.current.shortWeekdaySymbols  // ["Sun", "Mon", ..., "Sat"]
        // Rotate so Monday is first
        return Array(symbols[1...]) + [symbols[0]]
    }
}
