import SwiftUI

struct LogEntryRow: View {
    let entry: PomodoroEntry
    var onUpdateNotes: (String) -> Void
    var onUpdateType: (PomodoroEntry.EntryType) -> Void
    var onDelete: () -> Void

    @State private var isEditing = false
    @State private var editedNotes: String = ""

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

                // Type badge
                Text(entry.type.rawValue)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(colorForType(entry.type).opacity(0.15))
                    )
                    .foregroundStyle(colorForType(entry.type))

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

            // Notes
            if isEditing {
                editingView
            } else {
                notesView
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                isEditing = true
                editedNotes = entry.notes
            }) {
                Label("Edit Notes", systemImage: "pencil")
            }
            Menu("Change Type") {
                ForEach(allTypes, id: \.self) { type in
                    Button(action: {
                        onUpdateType(type)
                    }) {
                        if type == entry.type {
                            Label(type.rawValue, systemImage: "checkmark")
                        } else {
                            Text(type.rawValue)
                        }
                    }
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var notesView: some View {
        if entry.notes.isEmpty {
            Text("No notes")
                .font(.body)
                .foregroundStyle(.tertiary)
                .italic()
                .onTapGesture {
                    isEditing = true
                    editedNotes = entry.notes
                }
        } else {
            Text(entry.notes)
                .font(.body)
                .lineLimit(3)
                .onTapGesture {
                    isEditing = true
                    editedNotes = entry.notes
                }
        }
    }

    @ViewBuilder
    private var editingView: some View {
        VStack(alignment: .trailing, spacing: 6) {
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
                Button("Cancel") {
                    isEditing = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Save") {
                    onUpdateNotes(editedNotes)
                    isEditing = false
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .controlSize(.small)
            }
        }
    }
}
