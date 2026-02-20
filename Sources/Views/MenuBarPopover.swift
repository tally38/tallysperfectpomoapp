import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var timerManager: TimerManager
    var onShowLog: () -> Void
    var onShowSettings: () -> Void
    var onDismiss: () -> Void

    @State private var showCancelConfirmation = false
    @State private var focusMinutesText: String = ""

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)

    private var defaultFocusMinutes: Int {
        let val = UserDefaults.standard.integer(forKey: "focusDuration")
        return val > 0 ? val : 25
    }

    var body: some View {
        VStack(spacing: 16) {
            // Status label
            statusLabel

            // Timer display
            if timerManager.phase != .idle {
                timerDisplay
            }

            // Duration picker (idle only)
            if timerManager.phase == .idle {
                durationPicker
            }

            // Primary action
            primaryAction

            // Secondary actions when running
            if timerManager.phase != .idle {
                secondaryActions
            }

            Divider()

            // Bottom links
            bottomLinks
        }
        .padding(20)
        .frame(width: 280)
        .alert("Cancel Timer?", isPresented: $showCancelConfirmation) {
            Button("Cancel Timer", role: .destructive) {
                timerManager.cancelTimer()
            }
            Button("Keep Running", role: .cancel) {}
        } message: {
            Text("This will cancel the current session without logging it.")
        }
    }

    // MARK: - Components

    @ViewBuilder
    private var statusLabel: some View {
        switch timerManager.phase {
        case .idle:
            VStack(spacing: 4) {
                Text("🍅")
                    .font(.system(size: 40))
                Text("Ready to focus")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        case .focus:
            Text(timerManager.isPaused ? "Focus — Paused" : "Focus")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
        case .shortBreak:
            Text(timerManager.isPaused ? "Short Break — Paused" : "Short Break")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
        case .longBreak:
            Text(timerManager.isPaused ? "Long Break — Paused" : "Long Break")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
        }
    }

    @ViewBuilder
    private var timerDisplay: some View {
        Text(Formatters.formatCountdown(timerManager.remainingSeconds))
            .font(.system(size: 56, weight: .light, design: .monospaced))
            .foregroundStyle(timerManager.isPaused ? .secondary : .primary)
            .contentTransition(.numericText())
            .animation(.default, value: timerManager.remainingSeconds)
    }

    @ViewBuilder
    private var durationPicker: some View {
        HStack(spacing: 6) {
            TextField("", text: $focusMinutesText)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 48)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(6)
                .onSubmit { startWithEnteredDuration() }
            Text("min")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .onAppear { focusMinutesText = "\(defaultFocusMinutes)" }
    }

    private var enteredMinutes: Int? {
        if let val = Int(focusMinutesText), val > 0 { return val }
        return nil
    }

    private func startWithEnteredDuration() {
        let minutes = enteredMinutes ?? defaultFocusMinutes
        onDismiss()
        timerManager.startFocus(durationMinutes: minutes)
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch (timerManager.phase, timerManager.isPaused) {
        case (.idle, _):
            Button(action: { startWithEnteredDuration() }) {
                Text("Start Focus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .controlSize(.large)

        case (_, true):
            Button(action: { timerManager.resume() }) {
                Text("Resume")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .controlSize(.large)

        case (_, false):
            Button(action: { timerManager.pause() }) {
                Text("Pause")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.secondary)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private var secondaryActions: some View {
        Button(action: { showCancelConfirmation = true }) {
            Text("Cancel")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var bottomLinks: some View {
        HStack {
            Button(action: onShowLog) {
                Label("Pomo Log", systemImage: "list.bullet")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button(action: onShowSettings) {
                Label("Settings", systemImage: "gear")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                Label("Quit", systemImage: "power")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}
