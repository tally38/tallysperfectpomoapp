import Foundation
import Combine
import AppKit

@MainActor
class TimerManager: ObservableObject {
    @Published var phase: TimerPhase = .idle
    @Published var isPaused: Bool = false
    @Published var remainingSeconds: Int = 0
    @Published var completedPomosInCycle: Int = 0
    @Published var sessionType: PomodoroEntry.EntryType = .focus
    @Published var sessionNotes: String = ""

    /// Fires when a focus or break session completes
    let events = PassthroughSubject<TimerEvent, Never>()

    private var targetEndDate: Date?
    private var focusStartedAt: Date?
    private var focusDurationUsed: TimeInterval = 0
    private var storedRemaining: TimeInterval = 0
    private var tickCancellable: AnyCancellable?
    private var wakeCancellable: AnyCancellable?
    private var clockChangeCancellable: AnyCancellable?

    init() {
        subscribeToSystemEvents()
    }

    // MARK: - Public API

    func startFocus(durationMinutes: Int? = nil, type: PomodoroEntry.EntryType? = nil) {
        let minutes = durationMinutes ?? UserDefaults.standard.integer(forKey: "focusDuration")
        let duration = TimeInterval(minutes > 0 ? minutes : 25) * 60

        phase = .focus
        isPaused = false
        sessionType = type ?? .focus
        sessionNotes = ""
        focusStartedAt = Date()
        focusDurationUsed = duration
        targetEndDate = Date().addingTimeInterval(duration)
        startTicking()
    }

    func startBreak() {
        let longInterval = UserDefaults.standard.integer(forKey: "longBreakInterval")
        let interval = longInterval > 0 ? longInterval : 4
        let isLong = completedPomosInCycle > 0 && completedPomosInCycle % interval == 0

        let key = isLong ? "longBreakDuration" : "shortBreakDuration"
        let defaultMinutes = isLong ? 15 : 5
        let minutes = UserDefaults.standard.integer(forKey: key)
        let duration = TimeInterval(minutes > 0 ? minutes : defaultMinutes) * 60

        phase = isLong ? .longBreak : .shortBreak
        isPaused = false
        targetEndDate = Date().addingTimeInterval(duration)
        startTicking()
    }

    func pause() {
        guard !isPaused, phase != .idle, let endDate = targetEndDate else { return }
        isPaused = true
        storedRemaining = max(0, endDate.timeIntervalSinceNow)
        tickCancellable?.cancel()
        tickCancellable = nil
    }

    func resume() {
        guard isPaused, phase != .idle else { return }
        isPaused = false
        targetEndDate = Date().addingTimeInterval(storedRemaining)
        startTicking()
    }

    func cancelTimer() {
        phase = .idle
        isPaused = false
        sessionType = .focus
        sessionNotes = ""
        targetEndDate = nil
        focusStartedAt = nil
        focusDurationUsed = 0
        storedRemaining = 0
        remainingSeconds = 0
        tickCancellable?.cancel()
        tickCancellable = nil
    }

    func snooze() {
        tickCancellable?.cancel()
        tickCancellable = nil
        phase = .shortBreak
        isPaused = false
        targetEndDate = Date().addingTimeInterval(5 * 60)
        startTicking()
    }

    // MARK: - Timer Tick

    private func startTicking() {
        tickCancellable?.cancel()
        updateRemaining()

        tickCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateRemaining()
            }
    }

    private func updateRemaining() {
        guard let endDate = targetEndDate, !isPaused else { return }

        let remaining = endDate.timeIntervalSinceNow
        if remaining <= 0 {
            remainingSeconds = 0
            tickCancellable?.cancel()
            tickCancellable = nil
            handleTimerExpiry()
        } else {
            remainingSeconds = Int(ceil(remaining))
        }
    }

    private func handleTimerExpiry() {
        switch phase {
        case .focus:
            let startedAt = focusStartedAt ?? Date()
            let duration = focusDurationUsed
            let type = sessionType
            completedPomosInCycle += 1

            // Start break immediately
            startBreak()

            // Fire event (AppDelegate shows overlay and plays sound)
            events.send(.focusCompleted(startedAt: startedAt, duration: duration, type: type))

        case .shortBreak, .longBreak:
            let autoStart = UserDefaults.standard.bool(forKey: "autoStartFocus")

            if autoStart {
                startFocus()
            } else {
                phase = .idle
                targetEndDate = nil
                remainingSeconds = 0
            }

            events.send(.breakCompleted)

        case .idle:
            break
        }
    }

    // MARK: - System Events

    private func subscribeToSystemEvents() {
        // Wake from sleep
        wakeCancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateRemaining()
            }

        // System clock change
        clockChangeCancellable = NotificationCenter.default
            .publisher(for: .NSSystemClockDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateRemaining()
            }
    }
}
