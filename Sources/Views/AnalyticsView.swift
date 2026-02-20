import SwiftUI
import Charts

struct AnalyticsView: View {
    @ObservedObject var store: PomodoroStore

    @State private var weekOffset: Int = 0

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)
    private let dayOrder = AnalyticsCalculator.mondayBasedDayLabels()

    private var weekRange: (start: Date, end: Date) {
        AnalyticsCalculator.weekRange(offset: weekOffset)
    }

    private var chartData: [AnalyticsCalculator.DayTypeAggregate] {
        AnalyticsCalculator.aggregate(entries: store.entries, in: weekRange)
    }

    private var weekSummary: AnalyticsCalculator.WeekSummary {
        AnalyticsCalculator.weekSummary(entries: store.entries, weekOffset: weekOffset)
    }

    private var hasEntries: Bool {
        chartData.contains { $0.totalMinutes > 0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            weekNavigator

            Divider()

            if hasEntries {
                ScrollView {
                    VStack(spacing: 20) {
                        chartView
                            .frame(height: 220)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        summaryCard
                            .padding(.horizontal, 20)

                        Spacer()
                    }
                    .padding(.bottom, 16)
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartView: some View {
        Chart(chartData) { item in
            BarMark(
                x: .value("Day", item.dayLabel),
                y: .value("Minutes", item.totalMinutes)
            )
            .foregroundStyle(by: .value("Type", item.typeRawValue))
        }
        .chartXScale(domain: dayOrder)
        .chartForegroundStyleScale(domain: typeDomain, range: typeColors)
        .chartYAxisLabel("minutes")
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

    // MARK: - Summary Card

    @ViewBuilder
    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatters.formatDuration(weekSummary.dailyAverageMinutes * 60))
                    .font(.title3.weight(.semibold))
            }

            Spacer()

            if let pct = weekSummary.percentChange {
                HStack(spacing: 4) {
                    Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%+.0f%% vs last week", pct))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(pct >= 0 ? .green : .red)
            } else {
                Text("No prior week data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
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
