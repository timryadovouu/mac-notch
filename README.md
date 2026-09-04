<p align="center">
  <img src="Resources/AppIcon.png" width="150" alt="mac-notch logo" />
</p>

<h1 align="center">mac-notch</h1>

<p align="center">
  A lightweight, Dynamic-Island-style hub that lives right in your MacBook notch.<br/>
  Hover the notch and it expands; move away and it collapses. No Dock icon, no menu-bar icon.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/Swift-5.9-FA834D?logo=swift&logoColor=white" alt="Swift 5.9" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-3178C6" alt="SwiftUI + AppKit" />
  <img src="https://img.shields.io/badge/dependencies-none-2ecc71" alt="no dependencies" />
</p>

---

## Overview

**mac-notch** turns the empty space around the camera notch into a small control
center. Everything is a module you can jump between from a horizontal icon rail;
the coral gear opens a proper Settings window. It's a single Swift Package
executable — pure SwiftUI + AppKit, **no third-party dependencies**.

- Runs as an **accessory app** (`LSUIElement`) — invisible in the Dock and menu bar.
- Sits over the physical notch and morphs like the iPhone Dynamic Island.
- Works on notchless Macs and external displays too (a synthetic top-center notch).

## Modules

| Module             | What it does                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| ⏱ **Timer**        | Pomodoro with focus presets (5 / 10 / 15 / 25 / 30 / 60 min), 4 sessions before a long break. A live countdown shows to the right of the notch; each phase change slides a **Focus / Break** alert in from the left.                                                                                                                                                                                         |
| 📋 **Buffer**      | A persistent clipboard. Everything you copy is saved as a **real file** under the buffer folder, in a per-day `YYYY-MM-DD` subfolder — text, images, and any copied files. Click an entry to copy it back, or **drag it straight out** to Finder / any app. Per-row copy & delete on hover; "Finder" opens the folder, "Clear day" wipes today. Deletions made directly in the folder show up automatically. |
| 🎵 **Media**       | Now-playing + transport for **Spotify** (AppleScript) and **cmus** (`cmus-remote`). While something plays, a little **equalizer** pulses to the left of the notch.                                                                                                                                                                                                                                           |
| ✅ **Tasks**       | A local to-do list: add, complete, delete, restore — with a trash that keeps deleted items for a while.                                                                                                                                                                                                                                                                                                      |
| ⏳ **Screen Time** | Local, on-device usage tracking: it credits the frontmost app every second and shows ranked apps (with their icons), total time and app-switch count for the day. Resets at midnight.                                                                                                                                                                                                                        |
| 🖥 **System**       | Live CPU / RAM / storage gauges.                                                                                                                                                                                                                                                                                                                                                                             |

## The collapsed strip

Even when closed, the brow stays useful:

- **Right** — the Pomodoro countdown while a timer runs.
- **Left** — a pulsing equalizer while music plays, or a brief alert on copy / timer phase change.

## Settings

The coral **gear** opens a standalone window with:

- **Buffer folder** — where the clipboard is stored (default `~/Documents/localBuffer`).
- **Auto-clear age** — delete buffer day-folders older than _N_ days…
- **…or clear at end of day** — keep only today's folder.
- **Reset-to-default delay** — after this long without opening the notch, it reopens on the default tab.
- **Default tab** — which module opens by default.

## Install & run

Requires macOS 13+ and the Xcode command-line tools.

For development:

```bash
swift run
```

Build a double-clickable app (generates the icon, packages `mac-notch.app`):

```bash
./build-app.sh
open mac-notch.app
```

Quit from the red **Quit** button in the expanded panel.

## Permissions

- **Media → Spotify** uses AppleScript, so macOS will ask for **Automation** access
  the first time — approve it or the track/controls won't work. **cmus** needs
  `cmus-remote` on your `PATH`. Nothing else requires special permissions; Screen
  Time and everything else stay entirely on your Mac.

## Configuration

Most things live in Settings. Deeper defaults are in code:

- `Sources/MacNotch/PomodoroModel.swift` — timer lengths & presets
- `Sources/MacNotch/Settings.swift` — default values

## Project structure

```
Sources/MacNotch/
  main.swift / AppDelegate.swift      app entry (accessory policy, app icon)
  ScreenNotch.swift                   notch geometry (+ non-notch fallback)
  NotchController.swift               the window over the notch + hover logic
  NotchRootView.swift                 the brow, its morphing & the equalizer
  ExpandedPanel.swift                 icon rail + module hosting
  *Panel.swift                        per-module UI
  PomodoroModel / BufferManager /
  MediaController / AppUsageTracker /
  TodoStore / SystemStats             module logic
  Settings.swift / SettingsPanel.swift  settings model + window
Resources/AppIcon.png                 app icon source
build-app.sh                          release build → mac-notch.app
```

## Notes

Inspired by [macnotch.io](https://macnotch.io)
