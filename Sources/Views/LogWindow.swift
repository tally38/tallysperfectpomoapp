import SwiftUI

struct LogWindow: View {
    @ObservedObject var store: PomodoroStore
    @State private var showManualEntry = false
    @State private var selectedTab: LogTab = .log

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)

    enum LogTab: String, CaseIterable {
        case log = "Log"
        case analysis = "Analysis"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Pomo Log")
                    .font(.title2.weight(.semibold))

                Spacer()

                Picker("", selection: $selectedTab) {
                    ForEach(LogTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                Spacer()

                Button(action: { showManualEntry = true }) {
                    Label("Add Manual Pomo", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .opacity(selectedTab == .log ? 1 : 0)
                .allowsHitTesting(selectedTab == .log)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            switch selectedTab {
            case .log:
                if store.entries.isEmpty {
                    emptyState
                } else {
                    logList
                }
            case .analysis:
                AnalyticsView(store: store)
            }
        }
        .sheet(isPresented: $showManualEntry) {
            ManualEntryForm(store: store)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("🍅")
                .font(.system(size: 48))
            Text("No pomodoros yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start your first focus session!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var logList: some View {
        let groups = store.entriesGroupedByDay()

        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        LogEntryRow(
                            entry: entry,
                            onUpdateNotes: { newNotes in
                                store.updateNotes(id: entry.id, notes: newNotes)
                            },
                            onUpdateDuration: { newDuration in
                                store.updateDuration(id: entry.id, duration: newDuration)
                            },
                            onUpdateType: { newType in
                                store.updateType(id: entry.id, type: newType)
                            },
                            onDelete: {
                                store.deleteEntry(id: entry.id)
                            }
                        )
                    }
                } header: {
                    HStack {
                        Text(group.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(group.entries.count) pomo\(group.entries.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}
