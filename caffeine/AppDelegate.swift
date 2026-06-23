//
//  AppDelegate.swift
//  caffeine
//
//  Created on 2026/6/23.
//

import AppKit
import ServiceManagement

/// 菜单栏 UI 层：管理状态栏图标，区分左/右键，按需构建右键菜单。
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let controller = CaffeineController()
    private var statusItem: NSStatusItem!

    /// 当前需要显示倒计时的菜单项（激活某有限时长时），以及菜单打开期间的刷新定时器。
    private weak var countdownItem: NSMenuItem?
    private var countdownTimer: Timer?
    /// 倒计时项的基础标题（不含倒计时后缀）。注意：设置 attributedTitle 会改写 item.title，
    /// 故必须单独保存基础标题，避免每秒拼接时不断累积。
    private var countdownBaseTitle = ""

    /// 开机自启动状态的缓存。`SMAppService.mainApp.status` 在主线程同步查询会等待低优先级
    /// 后台线程，造成优先级反转告警，故改为后台异步刷新、菜单只读缓存。
    private var launchAtLoginEnabled = false

    /// 本地化文案的便捷取值（key 为英文源串，翻译见 Localizable.xcstrings）。
    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏图标。
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            // 同时接收左键与右键抬起事件，以便自行区分。
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon()

        // 状态变化（含定时到点自动关闭）时刷新图标。
        controller.onStateChange = { [weak self] in
            self?.updateIcon()
        }

        // 后台异步读取开机自启动状态，避免在主线程同步查询造成优先级反转。
        refreshLaunchAtLoginStatus()
    }

    /// 退出应用时仅释放防休眠状态（关闭断言），不改动已保存的偏好设置。
    func applicationWillTerminate(_ notification: Notification) {
        controller.deactivate()
    }

    // MARK: - 图标

    /// 根据左键默认策略决定图标实心/空心：
    /// - 定时 → 有激活状态即为实心
    /// - 合盖保持唤醒 → 仅看合盖开关是否勾选
    /// - 永久 → 有激活状态即为实心
    @MainActor
    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let isFilled: Bool
        switch controller.leftClickDefault {
        case .lidAwake:
            isFilled = controller.preventSleepWhenLidClosed
        case .timed, .indefinitely:
            isFilled = controller.isActive
        }
        let symbolName = isFilled ? "cup.and.saucer.fill" : "cup.and.saucer"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Caffeine")
        image?.isTemplate = true
        button.image = image
    }

    // MARK: - 点击处理

    /// 左键：切换防休眠；右键或 Control+左键：弹出菜单。
    @MainActor
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if isRightClick {
            // 临时挂上菜单并触发点击弹出，弹出结束后置回 nil，保证下次左键不弹菜单。
            statusItem.menu = buildMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            controller.handleLeftClick()
        }
    }

    // MARK: - 菜单构建

    /// 构建右键菜单。
    @MainActor
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        countdownItem = nil // 每次重建菜单先清空，下面按激活态重新记录

        // 1. 「保持亮屏时间」竖排预设项，点选即按该时长激活。
        for preset in CaffeineController.durationPresets {
            let item = NSMenuItem(title: localized(preset.title), action: #selector(selectDuration(_:)), keyEquivalent: "")
            item.target = self
            item.image = symbolImage("clock")
            item.representedObject = preset.seconds.map { NSNumber(value: $0) }
            item.state = isActiveDurationItem(preset.seconds) ? .on : .off
            // 记录正在倒计时的预设项。
            if item.state == .on, controller.remainingTime != nil {
                countdownItem = item
                countdownBaseTitle = item.title
            }
            menu.addItem(item)
        }
        // 「永久」也竖排在一级菜单。
        let foreverItem = NSMenuItem(title: localized("Indefinitely"), action: #selector(selectDuration(_:)), keyEquivalent: "")
        foreverItem.target = self
        foreverItem.image = symbolImage("infinity")
        foreverItem.representedObject = NSNumber(value: 0.0) // 0 表示永久
        foreverItem.state = (controller.isActive && controller.activeDuration == nil) ? .on : .off
        menu.addItem(foreverItem)

        // 「自定义 ▸」二级菜单：内含一个直接输入框，输入分钟数回车即激活。
        let customParent = NSMenuItem(title: localized("Custom"), action: nil, keyEquivalent: "")
        customParent.image = symbolImage("pencil")
        customParent.state = isActiveCustomDuration() ? .on : .off
        customParent.submenu = buildCustomSubmenu()
        // 自定义时长激活时，倒计时显示在「自定义」父项右侧。
        if customParent.state == .on, controller.remainingTime != nil {
            countdownItem = customParent
            countdownBaseTitle = customParent.title
        }
        menu.addItem(customParent)

        menu.addItem(.separator())

        // 2. 合盖也不休眠开关。
        let lidItem = NSMenuItem(title: localized("Keep awake when lid is closed"), action: #selector(toggleLidClosed(_:)), keyEquivalent: "")
        lidItem.target = self
        lidItem.image = symbolImage("laptopcomputer")
        lidItem.state = controller.preventSleepWhenLidClosed ? .on : .off
        menu.addItem(lidItem)

        menu.addItem(.separator())

        // 3. 「左键默认行为」子菜单。
        let leftClickItem = NSMenuItem(title: localized("Left-click default"), action: nil, keyEquivalent: "")
        leftClickItem.image = symbolImage("computermouse")
        leftClickItem.submenu = buildLeftClickSubmenu()
        menu.addItem(leftClickItem)

        // 4. 开机自启动开关。
        let loginItem = NSMenuItem(title: localized("Launch at Login"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.image = symbolImage("arrow.up.forward.app")
        loginItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        // 5. 关于 Caffeine。
        let aboutItem = NSMenuItem(title: localized("About Caffeine"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = symbolImage("info.circle")
        menu.addItem(aboutItem)

        // 6. 退出。
        let quitItem = NSMenuItem(title: localized("Quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = symbolImage("power")
        menu.addItem(quitItem)

        return menu
    }

    /// 生成菜单项用的 SF Symbol 模板图标（自动适配深浅色）。
    private func symbolImage(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    /// 构建「左键默认行为」子菜单：顺序与一级菜单一致（预设时长 → 永久 → 合盖保持唤醒）。
    @MainActor
    private func buildLeftClickSubmenu() -> NSMenu {
        let submenu = NSMenu()

        // 各定时时长
        for preset in CaffeineController.durationPresets {
            guard let seconds = preset.seconds else { continue }
            let item = NSMenuItem(title: localized(preset.title), action: #selector(selectLeftClickDefault(_:)), keyEquivalent: "")
            item.target = self
            item.image = symbolImage("clock")
            item.representedObject = NSNumber(value: seconds)
            item.state = controller.leftClickDefault == .timed(seconds) ? .on : .off
            submenu.addItem(item)
        }

        // 永久
        let foreverItem = NSMenuItem(title: localized("Indefinitely"), action: #selector(selectLeftClickDefault(_:)), keyEquivalent: "")
        foreverItem.target = self
        foreverItem.image = symbolImage("infinity")
        foreverItem.representedObject = NSNumber(value: CaffeineController.LeftClickDefault.indefinitely.raw)
        foreverItem.state = controller.leftClickDefault == .indefinitely ? .on : .off
        submenu.addItem(foreverItem)

        // 合盖保持唤醒（与上面各项互斥，仅配置左键默认动作，不立即执行）
        let lidItem = NSMenuItem(title: localized("Keep awake when lid is closed"), action: #selector(selectLeftClickDefault(_:)), keyEquivalent: "")
        lidItem.target = self
        lidItem.image = symbolImage("laptopcomputer")
        lidItem.representedObject = NSNumber(value: CaffeineController.LeftClickDefault.lidAwake.raw)
        lidItem.state = controller.leftClickDefault == .lidAwake ? .on : .off
        submenu.addItem(lidItem)

        return submenu
    }

    /// 构建「自定义」二级菜单：内含一个直接输入分钟数的输入框。
    @MainActor
    private func buildCustomSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let initialMinutes = isActiveCustomDuration()
            ? Int((controller.activeDuration ?? 0) / 60)
            : controller.lastCustomMinutes
        let inputView = CustomDurationMenuItemView(initialMinutes: initialMinutes)
        inputView.onStart = { [weak self] minutes in
            self?.controller.lastCustomMinutes = minutes
            self?.controller.activate(duration: TimeInterval(minutes) * 60)
        }
        let item = NSMenuItem()
        item.view = inputView
        submenu.addItem(item)
        return submenu
    }

    /// 判断某个时长是否为当前正在生效的激活时长（用于打勾）。
    @MainActor
    private func isActiveDurationItem(_ seconds: TimeInterval?) -> Bool {
        guard controller.isActive, let seconds else { return false }
        return controller.activeDuration == seconds
    }

    /// 判断当前激活的是否为「自定义时长」（既非永久，也不匹配任何预设）。
    @MainActor
    private func isActiveCustomDuration() -> Bool {
        guard controller.isActive, let active = controller.activeDuration else { return false }
        let presetSeconds = CaffeineController.durationPresets.compactMap { $0.seconds }
        return !presetSeconds.contains(active)
    }

    // MARK: - 菜单动作

    /// 点选某个预设时长：若当前正按该时长运行则关闭，否则按此时长激活（0 表示永久）。
    @MainActor
    @objc private func selectDuration(_ sender: NSMenuItem) {
        let seconds = (sender.representedObject as? NSNumber)?.doubleValue ?? 0
        let duration: TimeInterval? = seconds == 0 ? nil : seconds

        if controller.isActive, controller.activeDuration == duration {
            controller.deactivate()
            return
        }
        controller.activate(duration: duration)
    }

    /// 切换「合盖也不休眠」。
    @MainActor
    @objc private func toggleLidClosed(_ sender: NSMenuItem) {
        controller.preventSleepWhenLidClosed.toggle()
    }

    /// 设置左键默认动作（互斥单选，仅配置不立即执行）。
    @MainActor
    @objc private func selectLeftClickDefault(_ sender: NSMenuItem) {
        let raw = (sender.representedObject as? NSNumber)?.doubleValue ?? 0
        controller.leftClickDefault = CaffeineController.LeftClickDefault(raw: raw)
    }

    /// 切换「开机自启动」：通过 ServiceManagement 注册/取消注册登录项。
    /// SMAppService 调用放到后台线程，避免阻塞主线程造成优先级反转。
    @objc private func toggleLaunchAtLogin() {
        let enable = !launchAtLoginEnabled
        DispatchQueue.global(qos: .utility).async {
            do {
                if enable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("切换开机自启动失败：\(error)")
            }
            self.refreshLaunchAtLoginStatus()
        }
    }

    /// 在后台线程读取开机自启动状态并回到主线程更新缓存。
    private func refreshLaunchAtLoginStatus() {
        DispatchQueue.global(qos: .utility).async {
            let enabled = SMAppService.mainApp.status == .enabled
            DispatchQueue.main.async {
                self.launchAtLoginEnabled = enabled
            }
        }
    }

    /// 显示「关于 Caffeine」面板，介绍功能与合盖限制。
    @objc private func showAbout() {
        let attributed = NSAttributedString(
            string: localized("about.credits"),
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.labelColor
            ]
        )
        // LSUIElement 应用需主动激活，面板才会置于最前。
        NSApp.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: attributed])
    }

    /// 退出 App。
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - 倒计时（NSMenuDelegate）

    @MainActor
    func menuWillOpen(_ menu: NSMenu) {
        guard countdownItem != nil else { return }
        updateCountdown()
        // 菜单追踪期间需把定时器加入 .common 模式，否则不会触发。
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateCountdown() }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// 刷新倒计时项右侧的浅色剩余时间；若已不在定时激活态则恢复纯标题并停表。
    @MainActor
    private func updateCountdown() {
        guard let item = countdownItem, let remaining = controller.remainingTime, remaining > 0 else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            if let item = countdownItem {
                item.attributedTitle = nil
                item.title = countdownBaseTitle
            }
            return
        }
        // 始终基于保存的基础标题拼接，避免累积。
        item.attributedTitle = countdownTitle(for: countdownBaseTitle, remaining: remaining)
    }

    /// 构造「标题 + 右对齐浅色剩余时间」的富文本。
    @MainActor
    private func countdownTitle(for title: String, remaining: TimeInterval) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let timeText = formatRemaining(remaining)

        // 右对齐 tab stop 放在 标题宽度 + 间距 + 时间宽度 处。
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let timeWidth = (timeText as NSString).size(withAttributes: [.font: font]).width
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: titleWidth + 28 + timeWidth)]

        let result = NSMutableAttributedString(
            string: title,
            attributes: [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        )
        result.append(NSAttributedString(
            string: "\t" + timeText,
            attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph]
        ))
        return result
    }

    /// 把剩余秒数格式化为 MM:SS（不足 1 小时）或 H:MM:SS。
    @MainActor
    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
