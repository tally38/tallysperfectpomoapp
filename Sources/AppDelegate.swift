import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var overlayWindow: OverlayWindow?
    private var overlayDismissHandler: (() -> Void)?
    private var logWindow: NSWindow?
    private var settingsWindow: NSWindow?

    let timerManager = TimerManager()
    let pomodoroStore = PomodoroStore()
    let soundManager = SoundManager()

    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register UserDefaults defaults
        UserDefaults.standard.register(defaults: [
            "focusDuration": 25,
            "shortBreakDuration": 5,
            "longBreakDuration": 15,
            "longBreakInterval": 4,
            "autoStartFocus": false,
            "alertSound": "Glass",
            "showTimerInMenuBar": true,
            "blockingOverlay": false,
            "breakSnoozeMode": true,
            "focusIcon": "🧠"
        ])

        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        subscribeToTimerEvents()
        subscribeToMenuBarUpdates()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "🍅"
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 340)
        popover.behavior = .transient
        popover.animates = true

        let popoverView = MenuBarPopover(
            timerManager: timerManager,
            onShowLog: { [weak self] in
                self?.popover.performClose(nil)
                self?.showLogWindow()
            },
            onShowSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.showSettingsWindow()
            }
        )
        popover.contentViewController = NSHostingController(rootView: popoverView)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Menu Bar Updates

    private func subscribeToMenuBarUpdates() {
        // Update menu bar display whenever timer state changes
        Publishers.CombineLatest3(
            timerManager.$phase,
            timerManager.$isPaused,
            timerManager.$remainingSeconds
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] phase, isPaused, remaining in
            self?.updateMenuBarDisplay(phase: phase, isPaused: isPaused, remaining: remaining)
        }
        .store(in: &cancellables)
    }

    private func updateMenuBarDisplay(phase: TimerPhase, isPaused: Bool, remaining: Int) {
        guard let button = statusItem.button else { return }
        let showTimer = UserDefaults.standard.bool(forKey: "showTimerInMenuBar")
        let focusIcon = UserDefaults.standard.string(forKey: "focusIcon") ?? "🧠"
        let timeString = Formatters.formatCountdown(remaining)

        switch (phase, isPaused) {
        case (.idle, _):
            button.image = nil
            button.title = "🍅"

        case (.focus, false):
            if showTimer {
                button.image = nil
                button.title = "\(focusIcon) \(timeString)"
            }

        case (.focus, true):
            if showTimer {
                button.image = nil
                button.title = "⏸ \(timeString)"
            }

        case (.shortBreak, false), (.longBreak, false):
            if showTimer {
                button.image = nil
                button.title = "☕ \(timeString)"
            }

        case (.shortBreak, true), (.longBreak, true):
            if showTimer {
                button.image = nil
                button.title = "⏸☕ \(timeString)"
            }
        }
    }

    // MARK: - Timer Events

    private func subscribeToTimerEvents() {
        timerManager.events
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .focusCompleted(let startedAt, let duration):
                    self.soundManager.playCompletionSound()
                    self.showFocusCompleteOverlay(startedAt: startedAt, duration: duration)
                case .breakCompleted:
                    self.soundManager.playCompletionSound()
                    self.showBreakCompleteOverlay()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Overlay

    private func showFocusCompleteOverlay(startedAt: Date, duration: TimeInterval) {
        let saveAndDismiss: (String) -> Void = { [weak self] notes in
            guard let self else { return }
            let entry = PomodoroEntry(
                id: UUID(),
                startedAt: startedAt,
                duration: duration,
                notes: notes,
                type: .focus,
                manual: false
            )
            self.pomodoroStore.addEntry(entry)
            self.dismissOverlay()
        }

        let contentView = OverlayContentView(
            mode: .focusComplete,
            timerManager: timerManager,
            onSaveAndBreak: { notes in
                saveAndDismiss(notes)
            },
            onSaveAndSkipBreak: { [weak self] notes in
                guard let self else { return }
                let entry = PomodoroEntry(
                    id: UUID(),
                    startedAt: startedAt,
                    duration: duration,
                    notes: notes,
                    type: .focus,
                    manual: false
                )
                self.pomodoroStore.addEntry(entry)
                self.timerManager.cancelTimer()
                self.timerManager.startFocus()
                self.dismissOverlay()
            },
            onStartFocus: nil,
            onNotYet: nil,
            onClose: { notes in
                saveAndDismiss(notes)
            }
        )

        presentOverlay(contentView: contentView, escapeDismiss: { saveAndDismiss("") })
    }

    private func showBreakCompleteOverlay() {
        // Auto-dismiss focus-complete overlay if still open (saves with empty notes)
        if overlayWindow != nil {
            overlayDismissHandler?()
        }

        let autoStart = UserDefaults.standard.bool(forKey: "autoStartFocus")
        let snoozeMode = UserDefaults.standard.bool(forKey: "breakSnoozeMode")

        let dismissAction: () -> Void = { [weak self] in
            if autoStart {
                self?.timerManager.cancelTimer()
            }
            self?.dismissOverlay()
        }

        let contentView = OverlayContentView(
            mode: .breakComplete(snoozeMode: snoozeMode),
            timerManager: timerManager,
            onSaveAndBreak: nil,
            onSaveAndSkipBreak: nil,
            onStartFocus: { [weak self] in
                if !autoStart {
                    self?.timerManager.startFocus()
                }
                self?.dismissOverlay()
            },
            onNotYet: { [weak self] in
                if autoStart {
                    self?.timerManager.cancelTimer()
                }
                self?.dismissOverlay()
            },
            onSnooze: { [weak self] in
                self?.timerManager.snooze()
                self?.dismissOverlay()
            },
            onClose: { _ in
                dismissAction()
            }
        )

        presentOverlay(contentView: contentView, escapeDismiss: dismissAction)
    }

    private func presentOverlay(contentView: OverlayContentView, escapeDismiss: @escaping () -> Void) {
        let blocking = UserDefaults.standard.bool(forKey: "blockingOverlay")
        let overlay = OverlayWindow()
        let hostingView = NSHostingView(rootView: contentView)

        if blocking, let screen = NSScreen.main ?? NSScreen.screens.first {
            overlay.setFrame(screen.frame, display: true)
            overlay.isMovable = false
            overlay.isMovableByWindowBackground = false
        } else {
            overlay.setContentSize(hostingView.fittingSize)
            overlay.center()
        }

        overlay.contentView = hostingView
        self.overlayWindow = overlay
        self.overlayDismissHandler = escapeDismiss

        overlay.onEscape = { [weak self] in
            self?.overlayDismissHandler?()
        }

        overlay.alphaValue = 0
        overlay.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            overlay.animator().alphaValue = 1.0
        }
    }

    private func dismissOverlay() {
        guard let overlay = overlayWindow else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            overlay.animator().alphaValue = 0
        }, completionHandler: {
            overlay.orderOut(nil)
            Task { @MainActor [weak self] in
                // Only nil out if no new overlay has replaced this one
                if self?.overlayWindow === overlay {
                    self?.overlayWindow = nil
                }
            }
        })
    }

    // MARK: - Log Window

    func showLogWindow() {
        if let window = logWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let logView = LogWindow(store: pomodoroStore)
        let hostingController = NSHostingController(rootView: logView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Pomo Log"
        window.setContentSize(NSSize(width: 500, height: 600))
        window.minSize = NSSize(width: 400, height: 500)
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false

        self.logWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Settings Window

    func showSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 400, height: 380))
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
