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
            "showTimerInMenuBar": true
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
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Pomodoro Timer")
            button.image?.isTemplate = false
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Pomodoro Timer")?
                .withSymbolConfiguration(config)
            button.contentTintColor = NSColor(red: 232/255, green: 93/255, blue: 74/255, alpha: 1.0)
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
        let timeString = Formatters.formatCountdown(remaining)

        switch (phase, isPaused) {
        case (.idle, _):
            button.title = ""
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Pomodoro Timer")?
                .withSymbolConfiguration(config)
            button.contentTintColor = NSColor(red: 232/255, green: 93/255, blue: 74/255, alpha: 1.0)

        case (.focus, false):
            if showTimer {
                button.image = nil
                button.title = timeString
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
        let contentView = OverlayContentView(
            mode: .focusComplete,
            onSaveAndBreak: { [weak self] notes in
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
            onDismiss: nil
        )

        let escapeDismiss: () -> Void = { [weak self] in
            let entry = PomodoroEntry(
                id: UUID(),
                startedAt: startedAt,
                duration: duration,
                notes: "",
                type: .focus,
                manual: false
            )
            self?.pomodoroStore.addEntry(entry)
            self?.dismissOverlay()
        }

        presentOverlay(contentView: contentView, escapeDismiss: escapeDismiss)
    }

    private func showBreakCompleteOverlay() {
        let autoStart = UserDefaults.standard.bool(forKey: "autoStartFocus")

        let contentView = OverlayContentView(
            mode: .breakComplete(autoStartEnabled: autoStart),
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
            onDismiss: nil
        )

        let escapeDismiss: () -> Void = { [weak self] in
            if autoStart {
                self?.timerManager.cancelTimer()
            }
            self?.dismissOverlay()
        }

        presentOverlay(contentView: contentView, escapeDismiss: escapeDismiss)
    }

    private func presentOverlay(contentView: OverlayContentView, escapeDismiss: @escaping () -> Void) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let overlay = OverlayWindow(screen: screen)
        overlay.contentView = NSHostingView(rootView: contentView)
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
                self?.overlayWindow = nil
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
