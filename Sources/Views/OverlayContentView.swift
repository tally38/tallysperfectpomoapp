import SwiftUI

enum OverlayMode {
    case focusComplete
    case breakComplete(snoozeMode: Bool)
}

struct OverlayContentView: View {
    let mode: OverlayMode
    @ObservedObject var timerManager: TimerManager
    var duration: TimeInterval = 0
    var initialNotes: String = ""
    var initialType: PomodoroEntry.EntryType = .focus

    // Focus complete actions — pass (notes, editedDuration, type)
    var onSaveAndBreak: ((String, TimeInterval, PomodoroEntry.EntryType) -> Void)?
    var onSaveAndSkipBreak: ((String, TimeInterval, PomodoroEntry.EntryType) -> Void)?

    // Break complete actions
    var onStartFocus: (() -> Void)?
    var onNotYet: (() -> Void)?
    var onSnooze: (() -> Void)?

    // Close button / escape handler
    var onClose: ((String, TimeInterval, PomodoroEntry.EntryType) -> Void)?

    @State private var notes: String = ""
    @State private var durationText: String = ""
    @State private var selectedType: PomodoroEntry.EntryType = .focus
    @State private var breakWasRunning = false
    @State private var breakExpired = false
    @FocusState private var isNotesFocused: Bool

    @AppStorage("blockingOverlay") private var blockingOverlay = false

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)
    private let cardMaxWidth: CGFloat = 500

    private var allTypes: [PomodoroEntry.EntryType] {
        var types: [PomodoroEntry.EntryType] = [.focus, .meeting]
        let custom = UserDefaults.standard.stringArray(forKey: "customPomoTypes") ?? []
        types += custom.map { PomodoroEntry.EntryType(rawValue: $0) }
        return types
    }

    private var editedDuration: TimeInterval {
        guard let minutes = Int(durationText), minutes > 0 else {
            return duration
        }
        return TimeInterval(minutes * 60)
    }

    var body: some View {
        if blockingOverlay {
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                card
            }
        } else {
            card
        }
    }

    @ViewBuilder
    private var card: some View {
        VStack(spacing: 24) {
            switch mode {
            case .focusComplete:
                focusCompleteCard
            case .breakComplete(let snoozeMode):
                breakCompleteCard(snoozeMode: snoozeMode)
            }
        }
        .padding(32)
        .frame(width: cardMaxWidth)
        .overlay(alignment: .topTrailing) {
            Button(action: { onClose?(notes, editedDuration, selectedType) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color(nsColor: .separatorColor).opacity(0.5)))
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            durationText = "\(Int(duration / 60))"
            notes = initialNotes
            selectedType = initialType
            if timerManager.phase == .shortBreak || timerManager.phase == .longBreak {
                breakWasRunning = true
            }
            // Auto-focus the notes field with slight delay for window animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isNotesFocused = true
            }
        }
        .onChange(of: timerManager.phase) { newPhase in
            if newPhase == .shortBreak || newPhase == .longBreak {
                breakWasRunning = true
            }
            if breakWasRunning && newPhase != .shortBreak && newPhase != .longBreak {
                breakExpired = true
            }
        }
        .onChange(of: notes) { newValue in
            if case .focusComplete = mode {
                timerManager.sessionNotes = newValue
            }
        }
    }

    // MARK: - Focus Complete

    @ViewBuilder
    private var focusCompleteCard: some View {
        Text("Focus session complete!")
            .font(.title2.weight(.semibold))

        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Duration:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("", text: $durationText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.monospacedDigit())
                Text("min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text("Type:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $selectedType) {
                    ForEach(allTypes, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("What did you accomplish?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $notes)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .focused($isNotesFocused)
        }

        HStack(spacing: 12) {
            Button(action: { onSaveAndSkipBreak?(notes, editedDuration, selectedType) }) {
                Text(breakExpired ? "Save & Start Focus" : "Save & Skip Break")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(action: {
                if breakExpired {
                    timerManager.startBreak()
                }
                onSaveAndBreak?(notes, editedDuration, selectedType)
            }) {
                Text(breakExpired ? "Save & Take Another Break" : "Save & Take Break")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
        }

        if timerManager.phase == .shortBreak || timerManager.phase == .longBreak {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(.secondary)
                Text("Break: \(Formatters.formatCountdown(timerManager.remainingSeconds))")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if breakExpired {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(.secondary)
                Text("Break's over")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Text("⌘Enter to save · Esc to save & dismiss")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Break Complete

    @ViewBuilder
    private func breakCompleteCard(snoozeMode: Bool) -> some View {
        Text("Break's over!")
            .font(.title2.weight(.semibold))

        Text("Ready to focus?")
            .font(.body)
            .foregroundStyle(.secondary)

        HStack(spacing: 12) {
            if snoozeMode {
                Button(action: { onSnooze?() }) {
                    Text("Snooze (5 min)")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                Button(action: { onNotYet?() }) {
                    Text("Not Yet")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(action: { onStartFocus?() }) {
                Text("Start Focus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
        }

        Text("⌘Enter to start focus · Esc to dismiss")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
