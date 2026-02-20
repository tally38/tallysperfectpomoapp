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

    // MARK: - Aggregation

    /// Aggregates entries within the given range into per-day, per-type totals.
    /// Always returns entries for all 7 days (Mon–Sun), with 0 minutes for empty days.
    static func aggregate(entries: [PomodoroEntry], in range: (start: Date, end: Date)) -> [DayTypeAggregate] {
        let calendar = Calendar.current
        let weekEntries = entries.filter {
            $0.startedAt >= range.start && $0.startedAt <= range.end
        }

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
        referenceDate: Date = Date()
    ) -> Double {
        let calendar = Calendar.current
        let weekEntries = entries.filter {
            $0.startedAt >= range.start && $0.startedAt <= range.end
        }
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
        referenceDate: Date = Date()
    ) -> WeekSummary {
        let currentRange = weekRange(offset: weekOffset, referenceDate: referenceDate)
        let currentAvg = dailyAverage(entries: entries, in: currentRange, referenceDate: referenceDate)

        let priorRange = weekRange(offset: weekOffset - 1, referenceDate: referenceDate)
        let priorEntries = entries.filter {
            $0.startedAt >= priorRange.start && $0.startedAt <= priorRange.end
        }

        if priorEntries.isEmpty {
            return WeekSummary(
                dailyAverageMinutes: currentAvg,
                previousWeekDailyAverage: nil,
                percentChange: nil
            )
        }

        let priorAvg = dailyAverage(entries: entries, in: priorRange, referenceDate: referenceDate)
        let pctChange: Double? = priorAvg > 0 ? ((currentAvg - priorAvg) / priorAvg) * 100 : nil

        return WeekSummary(
            dailyAverageMinutes: currentAvg,
            previousWeekDailyAverage: priorAvg,
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
