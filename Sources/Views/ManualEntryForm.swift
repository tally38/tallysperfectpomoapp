import SwiftUI

struct ManualEntryForm: View {
    @ObservedObject var store: PomodoroStore
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var durationMinutes: Int = 25
    @State private var notes: String = ""
    @State private var selectedType: PomodoroEntry.EntryType = .focus

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)

    private var allTypes: [PomodoroEntry.EntryType] {
        var types: [PomodoroEntry.EntryType] = [.focus, .meeting]
        let custom = UserDefaults.standard.stringArray(forKey: "customPomoTypes") ?? []
        types += custom.map { PomodoroEntry.EntryType(rawValue: $0) }
        return types
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Manual Pomo")
                .font(.headline)

            Form {
                DatePicker("Date & Time", selection: $date)
                    .datePickerStyle(.field)

                Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 1...120)

                Picker("Type", selection: $selectedType) {
                    ForEach(allTypes, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 60, maxHeight: 100)
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
                }
            }
            .formStyle(.grouped)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    let entry = PomodoroEntry(
                        id: UUID(),
                        startedAt: date,
                        duration: TimeInterval(durationMinutes * 60),
                        notes: notes,
                        type: selectedType,
                        manual: true
                    )
                    store.addEntry(entry)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
