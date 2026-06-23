//
//  PowerAssertionManager.swift
//  caffeine
//
//  Created on 2026/6/23.
//

import Foundation
import IOKit.pwr_mgt

/// 电源断言管理器（低层）：仅负责通过 IOKit 创建/释放电源断言。
///
/// 设计参考 KeepingYouAwake：默认使用 `PreventUserIdleDisplaySleep` 断言保持系统/显示器唤醒；
/// 当 `preventSleepWhenLidClosed` 为真时，额外使用更强的 `PreventSystemSleep` 断言。
final class PowerAssertionManager {

    /// 当前是否持有断言（仅作内部重复保护）。
    private(set) var isHolding = false

    /// 防止显示器空闲休眠的断言 ID（持有期间始终创建）。
    private var displayAssertionID = IOPMAssertionID(0)
    /// 防止系统休眠（含合盖）的断言 ID（仅在开启合盖选项时创建）。
    private var systemAssertionID = IOPMAssertionID(0)

    /// 标记对应断言是否已创建，避免重复释放。
    private var hasDisplayAssertion = false
    private var hasSystemAssertion = false

    /// 开始持有断言。
    /// - Parameter preventSleepWhenLidClosed: 是否同时阻止合盖休眠。
    func begin(preventSleepWhenLidClosed: Bool) {
        guard !isHolding else { return }
        createAssertions(preventSleepWhenLidClosed: preventSleepWhenLidClosed)
        isHolding = true
    }

    /// 释放全部断言。
    func end() {
        guard isHolding else { return }
        releaseAssertions()
        isHolding = false
    }

    /// 在持有期间更新「合盖也不休眠」设置：先释放再按新设置重建。
    func update(preventSleepWhenLidClosed: Bool) {
        guard isHolding else { return }
        releaseAssertions()
        createAssertions(preventSleepWhenLidClosed: preventSleepWhenLidClosed)
    }

    // MARK: - 私有方法

    /// 根据设置创建电源断言。
    private func createAssertions(preventSleepWhenLidClosed: Bool) {
        let reason = "Caffeine 正在阻止 Mac 休眠" as CFString

        // 始终创建：防止显示器空闲休眠（等价于 KeepingYouAwake 的默认行为）。
        var displayID = IOPMAssertionID(0)
        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displayID
        )
        if displayResult == kIOReturnSuccess {
            displayAssertionID = displayID
            hasDisplayAssertion = true
        }

        // 可选：合盖也不休眠，使用更强的 PreventSystemSleep 断言。
        // 注意：在 Apple 芯片的 Mac 上，合盖休眠由磁吸传感器触发，属于硬件级强制行为，
        // 电源断言只能在「接通电源（通常还需外接显示器）」时尽力保持唤醒，无法完全绕过。
        if preventSleepWhenLidClosed {
            var systemID = IOPMAssertionID(0)
            let systemResult = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &systemID
            )
            if systemResult == kIOReturnSuccess {
                systemAssertionID = systemID
                hasSystemAssertion = true
            }
        }
    }

    /// 释放已创建的电源断言。
    private func releaseAssertions() {
        if hasDisplayAssertion {
            IOPMAssertionRelease(displayAssertionID)
            hasDisplayAssertion = false
        }
        if hasSystemAssertion {
            IOPMAssertionRelease(systemAssertionID)
            hasSystemAssertion = false
        }
    }
}
