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

---

> English | [中文](#中文)

Caffeine is a lightweight, modern menu bar utility that prevents your Mac from sleeping. Left-click to toggle, right-click to pick a duration — it's that simple.

## ✨ Features

- **Left-click toggle** — turn keep-awake on/off with a single click. Customize what left-click does: indefinite, timed, or toggle lid-closed mode.
- **Right-click menu** — choose from presets (5 min / 15 min / 1 hour), stay awake indefinitely, or enter a custom duration in minutes.
- **Countdown display** — when a timed preset is active, the menu shows the remaining time ticking down.
- **Lid-closed wake** — optionally keep the Mac awake even when the lid is closed (best-effort; Apple silicon typically requires AC power + external display).
- **Launch at login** — start automatically when you log in.
- **Multi-language** — English, 简体中文, 繁體中文, 日本語, Français, Deutsch, Español.
- **Native & lightweight** — built with Swift 6, AppKit, and IOKit power assertions. Zero external dependencies.

## 📸 Screenshot

<p align="center">
  <img src="https://github.com/user-attachments/assets/placeholder" alt="Screenshot" width="400" />
</p>

## 📥 Installation

### Download (Recommended)

Go to [Releases](https://github.com/your-username/caffeine/releases) and grab the latest `Caffeine.zip` or `Caffeine.dmg`.

### Build from Source

```bash
git clone https://github.com/your-username/caffeine.git
cd caffeine
xcodebuild -project caffeine.xcodeproj -scheme caffeine -configuration Release -derivedDataPath ./build clean build
open ./build/Build/Products/Release/caffeine.app
```

## ⌨️ Usage

| Action | Behavior |
|--------|----------|
| **Left-click icon** | Toggles keep-awake (customizable in right-click menu) |
| **Right-click icon** | Opens the full menu |
| **Select a duration** | Activates for that time; clicking again deactivates |
| **Choose "Custom"** | Enter any number of minutes |
| **"Keep awake when lid closed"** | Toggle lid-closed sleep prevention |
| **"Left-click default"** | Choose what left-click does (indefinite / timed / lid-closed toggle) |

## 🛠 Tech Stack

- **Swift 6** + **AppKit** — native macOS menu bar app
- **IOKit** — `IOPMAssertionCreateWithName` for system-level sleep prevention
- **SF Symbols** — native iconography, adapts to light/dark mode
- **ServiceManagement** — `SMAppService` for launch-at-login
- **Xcode 16** — project format

## 📄 License

MIT © [Your Name]

---

<h2 id="中文">☕ Caffeine（中文）</h2>

Caffeine 是一款轻量、现代的菜单栏防休眠工具。左键一键开关，右键选择时长 — 就是这么简单。

## ✨ 功能特性

- **左键切换** — 单击图标开关防休眠。可自定义左键行为：永久唤醒、定时唤醒、或切换合盖保持唤醒。
- **右键菜单** — 选择预设时长（5 分钟 / 15 分钟 / 1 小时）、永久保持、或输入自定义分钟数。
- **倒计时显示** — 定时激活时，菜单中实时显示剩余时间。
- **合盖保持唤醒** — 合上笔记本盖子也不休眠（尽力而为；Apple 芯片通常需接电源 + 外接显示器）。
- **开机自启动** — 登录后自动运行。
- **多语言支持** — 简体中文、繁體中文、English、日本語、Français、Deutsch、Español。
- **原生轻量** — 基于 Swift 6 + AppKit + IOKit，零外部依赖。

## 📥 安装

### 下载（推荐）

前往 [Releases](https://github.com/your-username/caffeine/releases) 下载最新的 `Caffeine.zip` 或 `Caffeine.dmg`。

### 从源码编译

```bash
git clone https://github.com/your-username/caffeine.git
cd caffeine
xcodebuild -project caffeine.xcodeproj -scheme caffeine -configuration Release -derivedDataPath ./build clean build
open ./build/Build/Products/Release/caffeine.app
```

## ⌨️ 使用方式

| 操作 | 效果 |
|------|------|
| **左键点击图标** | 切换防休眠开关（可在右键菜单中自定义默认行为） |
| **右键点击图标** | 打开完整菜单 |
| **选择时长** | 按时长激活；再次点击同一项则关闭 |
| **选择「自定义」** | 输入任意分钟数 |
| **「合盖保持唤醒」** | 切换合盖防休眠开关 |
| **「左键默认行为」** | 配置左键点击执行的动作 |

## 📄 开源协议

MIT © [你的名字]
