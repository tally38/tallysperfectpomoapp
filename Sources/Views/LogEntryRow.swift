import SwiftUI

struct LogEntryRow: View {
    let entry: PomodoroEntry
    var onUpdateNotes: (String) -> Void
    var onUpdateDuration: (TimeInterval) -> Void
    var onUpdateType: (PomodoroEntry.EntryType) -> Void
    var onDelete: () -> Void

    @State private var isEditing = false
    @State private var editedNotes: String = ""
    @State private var editedType: PomodoroEntry.EntryType = .focus
    @State private var editedDurationText: String = ""
    @State private var showDeleteConfirmation = false

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)

    private var allTypes: [PomodoroEntry.EntryType] {
        var types: [PomodoroEntry.EntryType] = [.focus, .meeting]
        let custom = UserDefaults.standard.stringArray(forKey: "customPomoTypes") ?? []
        types += custom.map { PomodoroEntry.EntryType(rawValue: $0) }
        return types
    }

    private func colorForType(_ type: PomodoroEntry.EntryType) -> Color {
        switch type {
        case .focus: return accentColor
        case .meeting: return .blue
        default: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                // Time
                Text(Formatters.formatTime(entry.startedAt))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                // Duration badge
                Text(Formatters.formatDuration(entry.duration))
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.15))
                    )
                    .foregroundStyle(accentColor)

                // Type badge — hidden while editing (shown in edit form instead)
                if !isEditing {
                    Text(entry.type.rawValue)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(colorForType(entry.type).opacity(0.15))
                        )
                        .foregroundStyle(colorForType(entry.type))
                }

                if entry.manual {
                    Text("manual")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                        )
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Notes / Edit form
            if isEditing {
                editingView
            } else {
                notesView
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { startEditing() }
        .contextMenu {
            Button(action: { startEditing() }) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Entry", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Are you sure you want to delete this entry? This cannot be undone.")
        }
    }

    private func startEditing() {
        editedNotes = entry.notes
        editedType = entry.type
        editedDurationText = "\(Int(entry.duration) / 60)"
        isEditing = true
    }

    private func saveEdits() {
        onUpdateNotes(editedNotes)
        if editedType != entry.type {
            onUpdateType(editedType)
        }
        if let minutes = Int(editedDurationText), minutes > 0 {
            let newDuration = TimeInterval(minutes * 60)
            if newDuration != entry.duration {
                onUpdateDuration(newDuration)
            }
        }
        isEditing = false
    }

    @ViewBuilder
    private var notesView: some View {
        if entry.notes.isEmpty {
            Text("No notes")
                .font(.body)
                .foregroundStyle(.tertiary)
                .italic()
        } else {
            Text(entry.notes)
                .font(.body)
                .lineLimit(3)
        }
    }

    @ViewBuilder
    private var editingView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    TextField("", text: $editedDurationText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 44)
                        .multilineTextAlignment(.center)
                        .font(.caption.monospacedDigit())
                    Text("min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("", selection: $editedType) {
                    ForEach(allTypes, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }

            TextEditor(text: $editedNotes)
                .font(.body)
                .frame(minHeight: 50, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    isEditing = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Save") {
                    saveEdits()
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .controlSize(.small)
            }
        }
    }
}
