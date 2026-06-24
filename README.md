<p align="center">
  <img src="caffeine/Assets.xcassets/AppIcon.appiconset/icon_128.png" alt="Caffeine" width="128" />
</p>

<h1 align="center">☕ Caffeine</h1>

<p align="center">
  <strong>Keep your Mac awake — simply.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/language-Swift%206-orange?logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License" />
</p>

<p align="center">
  <a href="README_CN.md">中文</a>
</p>

---

Caffeine is a lightweight, modern menu bar utility that prevents your Mac from sleeping. Left-click to toggle, right-click to pick a duration — it's that simple.

### ✨ Features

- **Left-click toggle** — turn keep-awake on/off with a single click. Customize what left-click does: indefinite, timed, or toggle lid-closed mode.
- **Right-click menu** — choose from presets (5 min / 15 min / 1 hour), stay awake indefinitely, or enter a custom duration in minutes.
- **Countdown display** — when a timed preset is active, the menu shows the remaining time ticking down.
- **Lid-closed wake** — optionally keep the Mac awake even when the lid is closed (best-effort; Apple silicon typically requires AC power + external display).
- **Launch at login** — start automatically when you log in.
- **Multi-language** — English, 简体中文, 繁體中文, 日本語, Français, Deutsch, Español.
- **Native & lightweight** — built with Swift 6, AppKit, and IOKit power assertions. Zero external dependencies.

### ⌨️ Usage

| Action | Behavior |
|--------|----------|
| **Left-click icon** | Toggles keep-awake (customizable in right-click menu) |
| **Right-click icon** | Opens the full menu |
| **Select a duration** | Activates for that time; clicking again deactivates |
| **Choose "Custom"** | Enter any number of minutes |
| **"Keep awake when lid closed"** | Toggle lid-closed sleep prevention |
| **"Left-click default"** | Choose what left-click does (indefinite / timed / lid-closed toggle) |

### ⚠️ Lid-closed wake — first-time setup

Keeping the Mac awake with the lid closed requires `pmset disablesleep`, which only runs as **root**. Caffeine ships a tiny privileged helper (an XPC `LaunchDaemon`) for this, so the first time you enable **"Keep awake when lid closed"** macOS will ask you to approve it:

1. Toggle **"Keep awake when lid closed"** in the menu.
2. Open **System Settings → General → Login Items & Extensions**.
3. Under **"Allow in the Background"**, turn **Caffeine** on.
4. Toggle the option again — the lid-closed setting now takes effect.

Notes:

- Verify it worked with `pmset -g live | grep SleepDisabled` — it should read `1` while active and `0` when off.
- The helper is registered via `SMAppService`. **Run the app from `/Applications`** (not straight from Xcode's DerivedData) — a stable install path avoids macOS Background Task Management caching a stale registration.
- If approval ever gets stuck after repeated rebuilds, reset the Background Task Management database with `sudo sfltool resetbtm` (system-wide; apps re-register on next launch) and relaunch.
- Apple silicon laptops generally also need **AC power + an external display** for the lid-closed assertion to hold.

### 📥 Install

**Download** — grab the latest `Caffeine.dmg` from [Releases](https://github.com/gosentetsu/Caffeine/releases).

**Build from source:**

```bash
git clone https://github.com/gosentetsu/Caffeine.git
cd Caffeine
xcodebuild -project caffeine.xcodeproj -scheme caffeine -configuration Release -derivedDataPath ./build clean build
open ./build/Build/Products/Release/Caffeine.app
```

### 🛠 Tech Stack

- **Swift 6** + **AppKit** — native macOS menu bar app
- **IOKit** — `IOPMAssertionCreateWithName` for system-level sleep prevention
- **SF Symbols** — native iconography, adapts to light/dark mode
- **ServiceManagement** — `SMAppService` for launch-at-login and the privileged helper
- **Privileged XPC helper** — a root `LaunchDaemon` runs `pmset disablesleep` for lid-closed wake

### 📄 License

MIT © [gosentetsu](https://github.com/gosentetsu)


