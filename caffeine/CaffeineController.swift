//
//  CaffeineController.swift
//  Caffeine
//
//  Created on 2026/6/23.
//

import Foundation

/// 防休眠的状态 / 计时 / 设置管理层。
///
/// 持有底层 `PowerAssertionManager`，对外提供激活、关闭、定时自动关闭，
/// 以及「合盖也不休眠」「左键默认行为」两项可持久化设置。
@MainActor
final class CaffeineController {

    /// 时长预设（标题, 秒数）。`nil` 秒数表示「一直保持（永久）」。
    /// 菜单与「左键默认行为」子菜单都复用这份定义。
    /// `title` 为本地化键（英文源串），实际显示时经 NSLocalizedString 翻译。
    static let durationPresets: [(title: String, seconds: TimeInterval?)] = [
        ("5 minutes", 5 * 60),
        ("15 minutes", 15 * 60),
        ("1 hour", 60 * 60)
    ]

    /// 左键默认动作（互斥单选）：决定左键点击执行什么。
    enum LeftClickDefault: Equatable {
        case indefinitely        // 永久保持唤醒
        case timed(TimeInterval) // 定时保持唤醒（秒）
        case lidAwake            // 合盖保持唤醒（无限期 + 合盖防睡）

        /// 与 UserDefaults 互转：永久=0，定时=正秒数，合盖=-1。
        init(raw: Double) {
            if raw < 0 {
                self = .lidAwake
            } else if raw == 0 {
                self = .indefinitely
            } else {
                self = .timed(raw)
            }
        }

        var raw: Double {
            switch self {
            case .indefinitely: return 0
            case .timed(let seconds): return seconds
            case .lidAwake: return -1
            }
        }
    }

    /// UserDefaults 键名。
    private enum Keys {
        static let preventLidClosed = "preventSleepWhenLidClosed"
        static let leftClickDefault = "leftClickDefault"
        static let lastCustomMinutes = "lastCustomMinutes"
    }

    let assertion = PowerAssertionManager()
    private let defaults = UserDefaults.standard

    /// 定时自动关闭用的计时器。
    private var timer: Timer?

    /// 状态变化回调（用于让 AppDelegate 刷新图标）。
    var onStateChange: (() -> Void)?

    /// 当前是否处于防休眠状态。
    private(set) var isActive = false

    /// 当前激活所用的时长（秒）。`nil` 表示永久。仅在 `isActive` 时有意义，用于菜单打勾。
    private(set) var activeDuration: TimeInterval?

    /// 定时激活的截止时刻。`nil` 表示永久或未激活，用于计算倒计时剩余时间。
    private(set) var activeUntil: Date?

    /// 距离自动关闭的剩余秒数；永久或未激活时为 `nil`。
    var remainingTime: TimeInterval? {
        guard let activeUntil else { return nil }
        return max(0, activeUntil.timeIntervalSinceNow)
    }

    init() {
        self.preventSleepWhenLidClosed = defaults.bool(forKey: Keys.preventLidClosed)
        self.leftClickDefault = LeftClickDefault(raw: defaults.double(forKey: Keys.leftClickDefault))
        self.lastCustomMinutes = defaults.integer(forKey: Keys.lastCustomMinutes)
    }

    // MARK: - 设置

    /// 是否允许合盖也不休眠（持久化）。修改后若正处于激活状态则立即重新应用断言。
    var preventSleepWhenLidClosed: Bool {
        didSet {
            defaults.set(preventSleepWhenLidClosed, forKey: Keys.preventLidClosed)
            if isActive {
                assertion.update(preventSleepWhenLidClosed: preventSleepWhenLidClosed)
            }
            onStateChange?()
        }
    }

    /// 左键点击的默认动作（持久化）。仅配置左键行为，设置时不立即执行。
    var leftClickDefault: LeftClickDefault {
        didSet {
            defaults.set(leftClickDefault.raw, forKey: Keys.leftClickDefault)
            onStateChange?()
        }
    }

    /// 上次输入的自定义分钟数（持久化），用于自定义输入框预填。
    var lastCustomMinutes: Int {
        didSet {
            defaults.set(lastCustomMinutes, forKey: Keys.lastCustomMinutes)
        }
    }

    // MARK: - 激活 / 关闭

    /// 左键点击：已激活则关闭；否则按左键默认动作执行。
    /// 「合盖保持唤醒」独立于防休眠激活/关闭，仅切换开关对勾。
    func handleLeftClick() {
        if leftClickDefault == .lidAwake {
            preventSleepWhenLidClosed.toggle()
            if preventSleepWhenLidClosed {
                activate(duration: nil)
            } else {
                deactivate()
            }
            return
        }

        if isActive {
            deactivate()
            return
        }
        switch leftClickDefault {
        case .indefinitely:
            activate(duration: nil)
        case .timed(let seconds):
            activate(duration: seconds)
        default:
            break
        }
    }

    /// 按指定时长激活防休眠。`duration` 为 `nil` 表示永久。
    func activate(duration: TimeInterval?) {
        timer?.invalidate()
        timer = nil

        if !isActive {
            assertion.begin(preventSleepWhenLidClosed: preventSleepWhenLidClosed)
            isActive = true
        }
        activeDuration = duration

        // 设置了有限时长则启动定时器，到点自动关闭，并记录截止时刻供倒计时使用。
        if let duration, duration > 0 {
            activeUntil = Date().addingTimeInterval(duration)
            let scheduled = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.deactivate()
                }
            }
            timer = scheduled
        } else {
            activeUntil = nil
        }

        onStateChange?()
    }

    /// 关闭防休眠并释放断言。
    func deactivate() {
        timer?.invalidate()
        timer = nil
        guard isActive else { return }
        assertion.end()
        isActive = false
        activeDuration = nil
        activeUntil = nil
        onStateChange?()
    }
}
