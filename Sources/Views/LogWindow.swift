import SwiftUI

struct LogWindow: View {
    @ObservedObject var store: PomodoroStore
    @State private var showManualEntry = false

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Pomo Log")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button(action: { showManualEntry = true }) {
                    Label("Add Manual Pomo", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Log entries
            if store.entries.isEmpty {
                emptyState
            } else {
                logList
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
