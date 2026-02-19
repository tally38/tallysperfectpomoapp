# Tally's Perfect Pomo App

A native macOS menu bar Pomodoro timer built with Swift and SwiftUI. It lives in your menu bar, shows a live countdown, delivers an overlay alert with sound when timers end, and keeps a persistent log of completed sessions with optional notes about what you accomplished.

## Features

- **Menu bar countdown** — see your remaining focus/break time at a glance
- **Partial-screen overlay alerts** — a dimmed backdrop with a centered card appears when timers end, impossible to miss but not hostile
- **Session notes** — record what you accomplished after each focus session
- **Persistent log** — browse all past sessions grouped by day, edit notes, delete entries
- **Manual entries** — retroactively log focus blocks you didn't record with the app
- **Custom entry types** — built-in Focus and Meeting types, plus create your own
- **Auto-start breaks** — break timer starts immediately when focus ends (no dead time)
- **Configurable durations** — focus, short break, long break, and long-break interval
- **Launch at login** — uses macOS 13+ `SMAppService`

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

Clone the repo and run:

```bash
# Debug build + run
make run

# Or build and run manually
swift build && .build/debug/TallysPerfectPomo
```

To create a proper `.app` bundle (needed for Launch at Login):

```bash
make bundle
open "Tally's Perfect Pomo.app"
```

Click on the app if it doesn't launch.

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
