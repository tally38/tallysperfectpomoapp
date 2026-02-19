import SwiftUI

struct LogEntryRow: View {
    let entry: PomodoroEntry
    var onUpdateNotes: (String) -> Void
    var onDelete: () -> Void

    @State private var isEditing = false
    @State private var editedNotes: String = ""

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)

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
