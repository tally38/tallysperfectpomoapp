import SwiftUI

enum OverlayMode {
    case focusComplete
    case breakComplete(autoStartEnabled: Bool)
}

struct OverlayContentView: View {
    let mode: OverlayMode

    // Focus complete actions
    var onSaveAndBreak: ((String) -> Void)?
    var onSaveAndSkipBreak: ((String) -> Void)?

    // Break complete actions
    var onStartFocus: (() -> Void)?
    var onNotYet: (() -> Void)?

    // Escape handler
    var onDismiss: (() -> Void)?

    @State private var notes: String = ""
    @FocusState private var isNotesFocused: Bool

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)
    private let cardMaxWidth: CGFloat = 500

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { /* prevent click-through, don't dismiss */ }

            // Centered card
            card
        }
    }

    @ViewBuilder
    private var card: some View {
        VStack(spacing: 24) {
            switch mode {
            case .focusComplete:
                focusCompleteCard
            case .breakComplete(let autoStart):
                breakCompleteCard(autoStartEnabled: autoStart)
            }
        }
        .padding(32)
        .frame(maxWidth: cardMaxWidth)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
        )
        .onAppear {
            // Auto-focus the notes field with slight delay for window animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isNotesFocused = true
            }
        }
    }

    // MARK: - Focus Complete

    @ViewBuilder
    private var focusCompleteCard: some View {
        Text("Focus session complete!")
            .font(.title2.weight(.semibold))

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
            Button(action: { onSaveAndSkipBreak?(notes) }) {
                Text("Save & Skip Break")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(action: { onSaveAndBreak?(notes) }) {
                Text("Save & Take Break")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
        }

        Text("⌘Enter to save · Esc to dismiss")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Break Complete

    @ViewBuilder
    private func breakCompleteCard(autoStartEnabled: Bool) -> some View {
        Text("Break's over!")
            .font(.title2.weight(.semibold))

        Text("Ready to focus?")
            .font(.body)
            .foregroundStyle(.secondary)

        HStack(spacing: 12) {
            if autoStartEnabled {
                Button(action: { onNotYet?() }) {
                    Text("Not Yet")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: { onStartFocus?() }) {
                    Text("Let's go!")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
            } else {
                Button(action: { onNotYet?() }) {
                    Text("Not Yet")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

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
        }

        Text("⌘Enter to continue · Esc to dismiss")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}
