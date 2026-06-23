<p align="center">
  <img src="caffeine/Assets.xcassets/AppIcon.appiconset/icon_128.png" alt="Caffeine" width="128" />
</p>

<h1 align="center">☕ Caffeine</h1>

<p align="center">
  <strong>让你的 Mac 保持唤醒 — 就这么简单。</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/language-Swift%206-orange?logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License" />
</p>

<p align="center">
  <a href="README.md">English</a>
</p>

---

Caffeine 是一款轻量、现代的菜单栏防休眠工具。左键一键开关，右键选择时长 — 就是这么简单。

### ✨ 功能

- **左键切换** — 单击图标开关防休眠。可自定义左键行为：永久唤醒、定时唤醒、或切换合盖保持唤醒。
- **右键菜单** — 选择预设时长（5 分钟 / 15 分钟 / 1 小时）、永久保持、或输入自定义分钟数。
- **倒计时显示** — 定时激活时，菜单中实时显示剩余时间。
- **合盖保持唤醒** — 合上笔记本盖子也不休眠（尽力而为；Apple 芯片通常需接电源 + 外接显示器）。
- **开机自启动** — 登录后自动运行。
- **多语言** — 简体中文、繁體中文、English、日本語、Français、Deutsch、Español。
- **原生轻量** — 基于 Swift 6 + AppKit + IOKit，零外部依赖。

### ⌨️ 使用

| 操作 | 效果 |
|------|------|
| **左键点击图标** | 切换防休眠开关（可在右键菜单中自定义默认行为） |
| **右键点击图标** | 打开完整菜单 |
| **选择时长** | 按时长激活；再次点击同一项则关闭 |
| **选择「自定义」** | 输入任意分钟数 |
| **「合盖保持唤醒」** | 切换合盖防休眠开关 |
| **「左键默认行为」** | 配置左键点击执行的动作 |

### 📥 安装

**下载** — 从 [Releases](https://github.com/gosentetsu/Caffeine/releases) 获取最新的 `Caffeine.dmg`。

**从源码编译：**

```bash
git clone https://github.com/gosentetsu/Caffeine.git
cd Caffeine
xcodebuild -project caffeine.xcodeproj -scheme caffeine -configuration Release -derivedDataPath ./build clean build
open ./build/Build/Products/Release/caffeine.app
```

### 🛠 技术栈

- **Swift 6** + **AppKit** — 原生 macOS 菜单栏应用
- **IOKit** — `IOPMAssertionCreateWithName` 系统级防休眠
- **SF Symbols** — 原生图标，自适应浅色/深色模式
- **ServiceManagement** — `SMAppService` 管理开机自启

### 📄 开源协议

MIT © [gosentetsu](https://github.com/gosentetsu)
