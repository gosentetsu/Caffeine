//
//  PowerAssertionManager.swift
//  caffeine
//
//  Created on 2026/6/23.
//

import Foundation
import IOKit.pwr_mgt

/// 电源断言管理器（低层）：通过 IOKit 断言 + pmset disablesleep 双机制防止休眠。
///
/// - IOKit `PreventUserIdleDisplaySleep`：防止显示器/系统空闲休眠（常规保持唤醒）。
/// - `pmset disablesleep 1`：系统级硬性禁止休眠（含合盖），需管理员权限。
///
/// 参考 Macchiato 的双锁设计：单独 IOKit 断言无法阻止 Apple Silicon 合盖传感器的
/// 硬件触发，必须配合 `pmset disablesleep` 才能真正实现合盖保持唤醒。
final class PowerAssertionManager {

    /// 当前是否持有 IOKit 断言。
    private(set) var isHolding = false

    /// 防止显示器空闲休眠的断言 ID。
    private var displayAssertionID = IOPMAssertionID(0)

    private var hasDisplayAssertion = false

    /// `pmset disablesleep` 是否已激活，避免重复执行 pmset。
    private var isSleepDisabled = false

    /// 后台串行队列，避免 pmset（需管理员授权弹窗）阻塞主线程。
    private let pmsetQueue = DispatchQueue(label: "com.caffeine.pmset")

    // MARK: - 公开接口

    /// 开始持有断言。
    /// - Parameter preventSleepWhenLidClosed: 是否同时阻止合盖休眠（启用 disablesleep）。
    func begin(preventSleepWhenLidClosed: Bool) {
        guard !isHolding else { return }
        createAssertion(preventSleepWhenLidClosed: preventSleepWhenLidClosed)
        if preventSleepWhenLidClosed {
            setDisableSleep(true)
        }
        isHolding = true
    }

    /// 释放全部断言并恢复 disablesleep。
    func end() {
        guard isHolding else { return }
        releaseAssertion()
        if isSleepDisabled {
            setDisableSleep(false)
        }
        isHolding = false
    }

    /// 在持有期间更新「合盖也不休眠」设置。
    func update(preventSleepWhenLidClosed: Bool) {
        guard isHolding else { return }
        releaseAssertion()
        createAssertion(preventSleepWhenLidClosed: preventSleepWhenLidClosed)
        setDisableSleep(preventSleepWhenLidClosed)
    }

    /// 应用启动时调用：强制重置 disablesleep（防止上次异常退出遗留）。
    /// 在后台执行，不阻塞启动。
    func resetDisableSleepOnLaunch() {
        pmsetQueue.async { [weak self] in
            self?.runDisableSleep(false)
        }
    }

    // MARK: - IOKit 断言

    private func createAssertion(preventSleepWhenLidClosed: Bool) {
        let reason = "Caffeine 正在阻止 Mac 休眠" as CFString

        var displayID = IOPMAssertionID(0)
        let type = preventSleepWhenLidClosed
            ? kIOPMAssertionTypePreventSystemSleep
            : kIOPMAssertionTypePreventUserIdleDisplaySleep

        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displayID
        )
        if result == kIOReturnSuccess {
            displayAssertionID = displayID
            hasDisplayAssertion = true
        }
    }

    private func releaseAssertion() {
        if hasDisplayAssertion {
            IOPMAssertionRelease(displayAssertionID)
            hasDisplayAssertion = false
        }
    }

    // MARK: - pmset disablesleep（系统级硬禁止）

    /// 调用 `pmset -a disablesleep 0/1`，需要管理员授权。
    /// 在后台队列异步执行，不阻塞主线程。
    private func setDisableSleep(_ disabled: Bool) {
        guard disabled != isSleepDisabled else { return }
        pmsetQueue.async { [weak self] in
            self?.runDisableSleep(disabled)
        }
    }

    /// 同步执行 pmset 命令（必须在 pmsetQueue 上调用）。
    private func runDisableSleep(_ disabled: Bool) {
        let value = disabled ? "1" : "0"
        let script = "do shell script \"pmset -a disablesleep \(value)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                isSleepDisabled = disabled
                NSLog("[Caffeine] pmset disablesleep \(value) 成功")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? "未知错误"
                // 用户取消授权（-128）时静默处理。
                if process.terminationStatus != -128 {
                    NSLog("[Caffeine] pmset disablesleep 失败 (exit \(process.terminationStatus)): \(errorMsg)")
                }
            }
        } catch {
            NSLog("[Caffeine] pmset 执行异常: \(error.localizedDescription)")
        }
    }
}
