# Tally's Perfect Pomo App — Product Requirements Document

## Overview

Tally's Perfect Pomo App is a native macOS menu bar Pomodoro timer. It lives in the macOS menu bar, shows a live countdown, delivers a partial-screen overlay alert with sound when timers end, and maintains a persistent log of completed pomodoros with optional notes about what was accomplished.

**Target platform:** macOS 13+ (Ventura and later)
**Technology:** Swift, SwiftUI, AppKit where needed
**Distribution:** Local build via Xcode or `swift build`

---

## Core User Flows

### 1. Starting a Pomodoro
1. User clicks the menu bar icon (shows 🍅 or a minimal tomato glyph when idle)
2. A dropdown/popover appears with a "Start Focus" button
3. Timer begins — the menu bar item updates to show remaining time (e.g. `23:41`)
4. User works until the timer ends

### 2. Focus Timer Ends
1. The **break timer immediately starts counting down** in the background — the user doesn't need to manually start it
2. A **partial-screen overlay** appears: dimmed backdrop (60% opacity) covering the full screen, with a centered card (~500px wide)
3. A short, pleasant notification sound plays (system sound, e.g. `Glass`)
4. The overlay card shows:
   - "Focus session complete!"
   - A text field to optionally record what was accomplished
   - **"Save & Take Break"** — dismisses overlay, break continues running
   - **"Save & Skip Break"** — dismisses overlay, cancels the break, immediately starts the next focus timer
5. If the user types notes, they are saved with the pomodoro record
6. The break timer is already running while the user is writing notes — no time is wasted

### 3. Break Timer Ends
1. A partial-screen overlay appears: "Break's over! Ready to focus?"
2. A short sound plays
3. **Behavior depends on the "Auto-start focus" setting:**
   - **If auto-start is ON:** The focus timer has already started. Buttons: **"Let's go!"** (dismiss overlay) and **"Snooze 5 min"** (see §Future: Snooze)
   - **If auto-start is OFF:** Buttons: **"Start Focus"** and **"Not Yet"** (returns to idle)

### 4. Viewing the Log
1. User clicks menu bar icon → selects "Pomo Log" from the dropdown
2. A window opens showing all recorded pomodoros in reverse chronological order
3. Each entry shows:
   - Date & time
   - Duration (e.g. "25 min")
   - What was accomplished (if recorded), or "No notes" in muted text
4. User can **edit** the notes on any past entry by clicking on it
5. User can **delete** entries

### 5. Adding a Manual Pomodoro
1. From the Pomo Log window, user clicks an **"+ Add Manual Pomo"** button
2. A form appears with:
   - Date & time picker (defaults to now)
   - Duration picker (defaults to 25 min)
   - Notes text field
3. User saves, and it appears in the log

---

## Detailed Requirements

### Menu Bar Behavior

| State | Menu Bar Display | Example |
|-------|-----------------|---------|
| Idle | Tomato icon (SF Symbol `circle.fill` tinted red, or a custom tiny tomato) | 🍅 |
| Focus running | Countdown timer in monospaced font | `23:41` |
| Break running | Countdown with break indicator | `☕ 4:12` |
| Paused | Blinking or dimmed timer | `⏸ 23:41` |

- Clicking the menu bar item opens a **popover** (not a full menu) with:
  - Current status and large timer display
  - Primary action button (Start Focus / Pause / Resume / Stop)
  - Secondary actions: "Pomo Log", "Settings"
  - If a timer is running: a "Cancel" option (with confirmation)

### Timer Defaults (Configurable in Settings)

| Timer | Default Duration |
|-------|-----------------|
| Focus | 25 minutes |
| Short Break | 5 minutes |
| Long Break | 15 minutes |
| Long break every N pomos | 4 |

### Timer Transition Behavior

**Focus → Break:** Break timer starts **immediately** when focus ends. The overlay is shown simultaneously, but the break clock is already ticking. If the user spends 2 minutes writing notes, they've already used 2 minutes of their break. This way there's no dead time.

**Break → Focus:** Controlled by the **"Auto-start focus sessions"** toggle in Settings (default: OFF).
- **OFF:** After break ends, overlay prompts user. App returns to idle until user manually starts the next focus session.
- **ON:** Focus timer starts immediately when break ends. Overlay notifies user but the clock is already running. User can dismiss and get to work, or (future) snooze.

### Partial-Screen Overlay

This is the key UI element — it must interrupt the user reliably without being hostile.

- **Window:** `NSPanel` with `styleMask: [.borderless]`, `level: .floating`
  - `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]`
  - `isOpaque: false`, `backgroundColor: .clear`
  - Frame set to `NSScreen.main!.frame`
- **Visual design:**
  - **Backdrop:** Full-screen semi-transparent dark layer (60% opacity black) — dims everything underneath
  - **Card:** Centered floating card, max ~500px wide, with rounded corners and soft shadow
  - Smooth fade-in animation (0.3s ease)
- **Interaction:**
  - Clicking the dimmed backdrop area does NOT dismiss (prevents accidental dismissal)
  - `Escape` key dismisses (treated as "Save with no notes & take break")
  - `⌘ Enter` submits the default action
  - Text field for notes is auto-focused so the user can immediately start typing
  - `Enter` in the text field inserts a newline (multiline notes); `⌘ Enter` submits

### Sound

- Play a system sound when a timer completes (e.g. `NSSound(named: "Glass")?.play()`)
- Optional: allow choosing from a few system sounds in Settings
- Keep it short and pleasant — not an alarm

### Pomo Log

- **Storage:** Local JSON file in `~/Library/Application Support/TallysPerfectPomo/pomo_log.json`
- **Data model per entry:**

```json
{
  "id": "uuid-string",
  "startedAt": "2025-02-19T14:30:00Z",
  "duration": 1500,
  "notes": "Finished the results section draft",
  "type": "focus",
  "manual": false
}
```

- **Log window:**
  - Standalone `NSWindow` (not the popover) — resizable, min size ~400×500
  - Grouped by day with section headers ("Today", "Yesterday", "Feb 17, 2025", etc.)
  - Each row: time, duration badge, notes (truncated with expand on click)
  - Inline editing of notes (click to edit)
  - Delete with right-click context menu or swipe
  - "+" button in toolbar for manual entry
  - Search/filter bar at the top (optional, nice-to-have)

### Manual Pomo Entry

- Date picker (defaults to current date/time)
- Duration stepper or picker (in minutes, defaults to 25)
- Notes text field (multiline)
- Save / Cancel buttons

### Settings

Accessible from the popover dropdown. Opens a small settings window.

| Setting | Type | Default |
|---------|------|---------|
| Focus duration | Stepper (minutes) | 25 |
| Short break duration | Stepper (minutes) | 5 |
| Long break duration | Stepper (minutes) | 15 |
| Long break every N pomos | Stepper | 4 |
| Auto-start focus sessions | Toggle | Off |
| Alert sound | Dropdown (system sounds) | Glass |
| Launch at login | Toggle | Off |
| Show timer in menu bar | Toggle | On |

- Store in `UserDefaults`

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘ Enter` | Submit overlay form (default action) |
| `Escape` | Dismiss overlay (save with no notes) |
| `Space` (when popover focused) | Start/Pause toggle |

---

## Architecture Notes

### App Structure

```
TallysPerfectPomo/
├── Package.swift  (or Xcode project)
├── Sources/
│   ├── TallysPerfectPomoApp.swift    # @main, NSApplicationDelegateAdaptor, menu bar setup
│   ├── AppDelegate.swift             # NSApplicationDelegate — manages status item, windows
│   ├── Models/
│   │   ├── PomodoroEntry.swift       # Codable data model
│   │   └── TimerState.swift          # Enum: idle, focus, shortBreak, longBreak, paused
│   ├── Services/
│   │   ├── TimerManager.swift        # ObservableObject — runs the timer, fires events
│   │   ├── PomodoroStore.swift       # Read/write pomo log JSON, CRUD operations
│   │   └── SoundManager.swift        # Play system sounds
│   ├── Views/
│   │   ├── MenuBarPopover.swift      # The popover shown when clicking menu bar
│   │   ├── OverlayWindow.swift       # Partial-screen overlay (AppKit NSPanel + SwiftUI content)
│   │   ├── OverlayContentView.swift  # The centered card shown in the overlay
│   │   ├── LogWindow.swift           # Pomo log viewer
│   │   ├── LogEntryRow.swift         # Individual log row
│   │   ├── ManualEntryForm.swift     # Add manual pomo
│   │   └── SettingsView.swift        # Settings window
│   └── Utilities/
│       └── Formatters.swift          # Time formatting helpers
```

### Key Implementation Details

1. **Menu bar item:** Use `NSStatusBar.system.statusItem(withLength: .variable)`. Update the title on a 1-second Timer publisher. Use `NSPopover` for the dropdown.

2. **Overlay window:** Create an `NSPanel` with:
   - `styleMask: [.borderless]`
   - `level: .floating` (or `.screenSaver` if floating isn't aggressive enough)
   - `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]`
   - `isOpaque: false`, `backgroundColor: .clear`
   - Frame set to `NSScreen.main!.frame`
   - Host a SwiftUI view inside via `NSHostingView`
   - The SwiftUI view renders the dimmed backdrop + centered card

3. **Timer logic:**
   - Store the **target end time** (`Date`), not remaining seconds — this correctly handles laptop sleep/wake
   - Use `Combine`'s `Timer.publish(every: 1, on: .main, in: .common)` to update display
   - When focus ends: immediately set the break target end time, THEN show the overlay
   - When break ends: check `autoStartFocus` setting to decide behavior

4. **Persistence:** Simple `Codable` JSON read/write to `~/Library/Application Support/TallysPerfectPomo/pomo_log.json`. Load on app start, write after each mutation. No Core Data needed.

5. **Launch at login:** Use `SMAppService.mainApp` (macOS 13+) for modern login item registration.

---

## Future Features (v2)

### Snooze for Focus Sessions
When a break ends and the overlay appears prompting the user to start a focus session:
- Add a **"Snooze 5 min"** button (or configurable snooze duration)
- Snooze dismisses the overlay and starts a mini-timer
- When the snooze timer ends, the overlay reappears with the same prompt
- Multiple consecutive snoozes should be allowed
- Snoozed time should NOT count as break or focus time
- This is most useful when `autoStartFocus` is ON — the user can say "not yet" without fully disengaging from the pomo cycle

### Other Future Ideas
- Log scalability: as the JSON log grows over months/years, consider pagination, lazy loading, archiving old entries, or migrating to SQLite
- Statistics / charts (pomos per day/week, streaks)
- Export log to CSV
- Global keyboard shortcut to start/pause (e.g. `⌃⌥P`)
- Integration with macOS Focus modes

---

## Non-Goals (Out of Scope)

- Syncing across devices
- iOS companion app
- Integration with calendars or task managers
- Menubar-only mode without overlay (the overlay is the whole point)

---

## Design Direction

**Aesthetic:** Warm minimal. A well-made desk tool, not a productivity SaaS dashboard.

- Dark mode primary (respect system appearance setting)
- Rounded corners, soft shadows, generous padding
- Monospaced or semi-monospaced font for the timer (SF Mono or similar)
- Warm accent color — muted tomato red (`#E85D4A` or similar), not aggressive
- The overlay backdrop should feel calm but unmissable — dimmed dark layer, centered light card
- Minimal chrome in the popover — just the essentials
- The log should feel like a journal, not a spreadsheet

---

## Success Criteria

The app is done when:
1. ✅ Timer countdown is visible in the macOS menu bar during sessions
2. ✅ Partial-screen overlay (dimmed backdrop + centered card) appears when any timer ends
3. ✅ A sound plays when timers end
4. ✅ Break timer auto-starts immediately when focus ends (no waiting)
5. ✅ Auto-start focus after break is toggle-able in settings (default: off)
6. ✅ User can record notes about what they accomplished after each focus session
7. ✅ All pomodoros (with notes) are saved and viewable in a log window
8. ✅ User can add manual pomodoro entries with custom date, duration, and notes
9. ✅ User can edit and delete log entries
10. ✅ Timer durations are configurable
11. ✅ App feels native, fast, and not annoying to use
