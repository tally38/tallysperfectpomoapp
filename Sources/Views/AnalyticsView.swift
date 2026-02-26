import SwiftUI
import Charts

struct AnalyticsView: View {
    @ObservedObject var store: PomodoroStore

    @State private var weekOffset: Int = 0
    @State private var selectedTypeFilter: PomodoroEntry.EntryType? = nil
    @State private var hoveredDay: String? = nil

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)
    private let dayOrder = AnalyticsCalculator.mondayBasedDayLabels()

    private var typeFilterSet: Set<PomodoroEntry.EntryType>? {
        guard let selected = selectedTypeFilter else { return nil }
        return [selected]
    }

    private var allTypes: [PomodoroEntry.EntryType] {
        let typesInEntries = Set(store.entries.map(\.type))
        var types: [PomodoroEntry.EntryType] = [.focus, .meeting]
        for t in typesInEntries where t != .focus && t != .meeting {
            types.append(t)
        }
        return types
    }

    private var weekRange: (start: Date, end: Date) {
        AnalyticsCalculator.weekRange(offset: weekOffset)
    }

    private var chartData: [AnalyticsCalculator.DayTypeAggregate] {
        AnalyticsCalculator.aggregate(entries: store.entries, in: weekRange, typeFilter: typeFilterSet)
    }

    private var weekSummary: AnalyticsCalculator.WeekSummary {
        AnalyticsCalculator.weekSummary(entries: store.entries, weekOffset: weekOffset, typeFilter: typeFilterSet)
    }

    private var todayComparison: AnalyticsCalculator.TodayComparison {
        AnalyticsCalculator.todayVsRecent(entries: store.entries, typeFilter: typeFilterSet)
    }

    private var weekdayAvg: Double {
        AnalyticsCalculator.weekdayDailyAverage(entries: store.entries, in: weekRange, typeFilter: typeFilterSet)
    }

    private var hasEntries: Bool {
        chartData.contains { $0.totalMinutes > 0 }
    }

    // MARK: - Hover Helpers

    private func dayTotal(for dayLabel: String) -> Double {
        chartData.filter { $0.dayLabel == dayLabel }.reduce(0) { $0 + $1.totalMinutes }
    }

    private func dateForDay(_ dayLabel: String) -> Date? {
        guard let index = dayOrder.firstIndex(of: dayLabel) else { return nil }
        return Calendar.current.date(byAdding: .day, value: index, to: weekRange.start)
    }

    private func dayComparison(for dayLabel: String) -> AnalyticsCalculator.TodayComparison? {
        guard let dayDate = dateForDay(dayLabel) else { return nil }
        let refDate = Calendar.current.date(byAdding: .hour, value: 12, to: dayDate)!
        return AnalyticsCalculator.todayVsRecent(entries: store.entries, referenceDate: refDate, typeFilter: typeFilterSet)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            weekNavigator

            Divider()

            if hasEntries {
                ScrollView {
                    VStack(spacing: 16) {
                        // Today section
                        if weekOffset == 0 {
                            sectionDivider("TODAY")
                                .padding(.top, 8)

                            todayCard
                                .padding(.horizontal, 20)
                        }

                        // Week section
                        sectionDivider("THIS WEEK")
                            .padding(.top, weekOffset == 0 ? 0 : 8)

                        chartView
                            .frame(height: 220)
                            .padding(.horizontal, 20)

                        if let hoveredDay {
                            dayDetailCard(for: hoveredDay)
                                .padding(.horizontal, 20)
                        }

                        weekAveragesRow
                            .padding(.horizontal, 20)

                        Spacer()
                    }
                    .padding(.bottom, 16)
                    .animation(.easeInOut(duration: 0.15), value: hoveredDay)
                }
            } else {
                emptyState
            }
        }
    }

    // MARK: - Week Navigator

    @ViewBuilder
    private var weekNavigator: some View {
        HStack {
            Button(action: { weekOffset -= 1 }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Spacer()

            Text("Week of \(Formatters.formatMediumDate(weekRange.start))")
                .font(.subheadline.weight(.medium))

            Spacer()

            Button(action: { weekOffset += 1 }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(weekOffset >= 0)

            typeFilterPicker
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Type Filter

    @ViewBuilder
    private var typeFilterPicker: some View {
        Picker("Filter", selection: $selectedTypeFilter) {
            Text("All").tag(PomodoroEntry.EntryType?.none)
            ForEach(allTypes, id: \.self) { type in
                Text(type.rawValue.capitalized).tag(PomodoroEntry.EntryType?.some(type))
            }
        }
        .pickerStyle(.menu)
        .frame(width: 100)
    }

    // MARK: - Section Dividers

    private func sectionDivider(_ title: String) -> some View {
        HStack(spacing: 8) {
            VStack { Divider() }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
            VStack { Divider() }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartView: some View {
        Chart {
            ForEach(chartData) { item in
                BarMark(
                    x: .value("Day", item.dayLabel),
                    y: .value("Minutes", item.totalMinutes)
                )
                .foregroundStyle(by: .value("Type", item.typeRawValue))
                .opacity(hoveredDay == nil || item.dayLabel == hoveredDay ? 1.0 : 0.4)
            }

            if let hoveredDay {
                RuleMark(x: .value("Selected", hoveredDay))
                    .foregroundStyle(.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .top, alignment: .center) {
                        let total = dayTotal(for: hoveredDay)
                        Text(Formatters.formatLongDuration(total * 60))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.1), radius: 2)
                            )
                    }
            }
        }
        .chartXScale(domain: dayOrder)
        .chartForegroundStyleScale(domain: typeDomain, range: typeColors)
        .chartYAxisLabel("minutes")
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            if let day: String = proxy.value(atX: location.x) {
                                hoveredDay = day
                            } else {
                                hoveredDay = nil
                            }
                        case .ended:
                            hoveredDay = nil
                        }
                    }
            }
        }
    }

    private var typeDomain: [String] {
        Set(chartData.map(\.typeRawValue)).sorted()
    }

    private var typeColors: [Color] {
        typeDomain.map { colorForType($0) }
    }

    private func colorForType(_ typeRaw: String) -> Color {
        switch typeRaw {
        case PomodoroEntry.EntryType.focus.rawValue: return accentColor
        case PomodoroEntry.EntryType.meeting.rawValue: return .blue
        default: return .purple
        }
    }

    // MARK: - Today Card

    @ViewBuilder
    private var todayCard: some View {
        let comparison = todayComparison
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatters.formatLongDuration(comparison.todayMinutes * 60))
                    .font(.title3.weight(.semibold))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("7-day avg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatters.formatLongDuration(comparison.recentDailyAverage * 60))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let pct = comparison.percentChange {
                HStack(spacing: 4) {
                    Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%+.0f%%", pct))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(pct >= 0 ? .green : .red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Day Detail Card (hover)

    @ViewBuilder
    private func dayDetailCard(for dayLabel: String) -> some View {
        if let comparison = dayComparison(for: dayLabel),
           let dayDate = dateForDay(dayLabel) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(dayLabel) \u{2013} \(Formatters.formatMediumDate(dayDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formatters.formatLongDuration(comparison.todayMinutes * 60))
                        .font(.title3.weight(.semibold))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Prior 7-day avg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formatters.formatLongDuration(comparison.recentDailyAverage * 60))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let pct = comparison.percentChange {
                    HStack(spacing: 4) {
                        Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%+.0f%%", pct))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(pct >= 0 ? .green : .red)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Week Averages

    @ViewBuilder
    private var weekAveragesRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Avg per Day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(Formatters.formatLongDuration(weekSummary.dailyAverageMinutes * 60))
                        .font(.title3.weight(.semibold))
                    Spacer()
                    if let pct = weekSummary.percentChange {
                        HStack(spacing: 4) {
                            Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(String(format: "%+.0f%%", pct))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(pct >= 0 ? .green : .red)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Weekday Avg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatters.formatLongDuration(weekdayAvg * 60))
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
            )
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("📊")
                .font(.system(size: 48))
            Text("No data this week")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Complete some focus sessions to see your stats!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
