# Tally's Perfect Pomo App

A native macOS menu bar Pomodoro timer built with Swift and SwiftUI. It lives in your menu bar, shows a live countdown, delivers an overlay alert with sound when timers end, and keeps a persistent log of completed sessions with optional notes about what you accomplished.

## Why I Made This

Existing pomodoro apps didn't let me do exactly what I wanted: keep track of what I did in each session and manually record focus blocks that I didn't capture with the app, so I could maintain an accurate log of my focus and tasks. Rather than hunting for an app with the right combination of features, I built one in about an hour... **I literally put a PRD in a directory and a functional app apeared.**

### The Workflow

1. Told Claude the features I wanted in a pomo app that were different from the one I already used, and asked for a PRD
2. Talked with Claude to refine the PRD
3. Saved the resulting PRD in a directory called tallysperfectpomoapp
4. Told Claude Code to build the app in the directory. It found the PRD and generated a plan
5. Reviewed Claude's plan and had Codex review Claude's plan independently
7. Fed Codex's feedback back into Claude to fix the flagged bugs/issues
8. Claude updated the plan, I approved it, and it built the app

The only things I needed to fix after the initial version were 1. Making the menu bar icon color dynamic so it shows up on both light and dark menu bars, and 2. adding a "Quit App" option to the menu. Everything else worked out of the box.

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+

## Getting Started

Clone the repo, build, and run:

```bash
make bundle && open "Tally's Perfect Pomo.app"
```

That's it! The `.app` bundle is also needed for Launch at Login to work. Click on the app if it doesn't launch.

For development, you can skip the bundle step:

```bash
# Debug build + run
make run

# Or build and run manually
swift build && .build/debug/TallysPerfectPomo
```

## Features

- **Menu bar countdown** — see your remaining focus/break time at a glance, with a configurable tomato icon
- **Draggable floating panel** — the main control panel floats above your work and can be repositioned
- **Overlay alerts** — a dimmed backdrop with a centered card appears when timers end, impossible to miss but not hostile
- **Session scratch pad** — jot notes while you're focusing, they carry over to the session log when the timer ends
- **Inline editing** — edit notes, duration, and session type directly in the log or the overlay card
- **Persistent log** — browse all past sessions grouped by day, swipe to delete
- **Analytics** — weekly focus chart with type filtering, today vs. 7-day comparison, and hover details
- **Manual entries** — retroactively log focus blocks you didn't capture with the timer
- **Custom entry types** — built-in Focus and Meeting types, plus create your own
- **Custom focus durations** — pick a one-off duration when starting a session, or change the defaults in settings
- **Break snooze** — extend a break without resetting the long-break cycle
- **Auto-start breaks** — break timer starts immediately when focus ends (no dead time)
- **Launch at login** — uses macOS 13+ `SMAppService`

## Running Tests

```bash
make test
# or
swift test
```

## Project Structure

```
Sources/
├── TallysPerfectPomoApp.swift   # @main SwiftUI App entry point
├── AppDelegate.swift            # NSStatusItem, popover, overlay, windows
├── Models/
│   ├── TimerState.swift         # idle, focus, shortBreak, longBreak, paused
│   └── PomodoroEntry.swift      # Codable data model + entry types
├── Services/
│   ├── TimerManager.swift       # Timer logic (stores target end date, not remaining seconds)
│   ├── PomodoroStore.swift      # JSON CRUD for the pomo log
│   └── SoundManager.swift       # System sound playback
├── Views/
│   ├── MenuBarPopover.swift     # Popover shown when clicking the menu bar icon
│   ├── OverlayWindow.swift      # NSPanel subclass for the overlay
│   ├── OverlayContentView.swift # Centered card content
│   ├── LogWindow.swift          # Pomo log viewer
│   ├── LogEntryRow.swift        # Individual log entry row
│   ├── ManualEntryForm.swift    # Add manual pomo form
│   └── SettingsView.swift       # Settings window
└── Utilities/
    └── Formatters.swift         # Time formatting helpers

Tests/
├── FormattersTests.swift
├── PomodoroStoreTests.swift
└── TimerManagerTests.swift
```

## Data Storage

Session logs are stored as JSON at:

```
~/Library/Application Support/TallysPerfectPomo/pomo_log.json
```

Settings are stored in `UserDefaults`.

## Support

If you find this useful, you can [buy me a coffee](https://buymeacoffee.com/talgal) ☕
