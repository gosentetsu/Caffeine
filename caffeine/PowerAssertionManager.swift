//
//  PowerAssertionManager.swift
//  Caffeine
//
//  Created on 2026/6/23.
//

import Foundation
import IOKit.pwr_mgt

/// 电源断言管理器：通过 IOKit 断言 + 特权 Helper 的 pmset disablesleep 双机制防止休眠。
///
/// - IOKit 断言：防止显示器/系统空闲休眠（常规保持唤醒）。
/// - 特权 XPC Helper → `pmset disablesleep 1`：系统级硬性禁止休眠（含合盖）。
///
/// 参考 Macchiato：单独 IOKit 断言无法阻止 Apple Silicon 合盖传感器的硬件触发。
/// 特权 Helper 以 LaunchDaemon 运行，首次需用户在「系统设置」中批准。
final class PowerAssertionManager {

    private(set) var isHolding = false

    private var assertionID = IOPMAssertionID(0)
    private var hasAssertion = false

    /// `pmset disablesleep` 是否已激活。
    private var isSleepDisabled = false

    /// Helper 是否正在等待用户批准（用于 UI 提示）。
    private(set) var needsApproval = false {
        didSet {
            if needsApproval { onApprovalNeeded?() }
        }
    }

    /// 需要用户批准 Helper 时的回调。
    var onApprovalNeeded: (() -> Void)?

    private let helper = PowerHelperClient.shared

    // MARK: - 公开接口

    func begin(preventSleepWhenLidClosed: Bool) {
        guard !isHolding else { return }
        createAssertion(preventSleepWhenLidClosed: preventSleepWhenLidClosed)
        isHolding = true
        if preventSleepWhenLidClosed {
            setDisableSleep(true)
        }
    }

    func end() {
        guard isHolding else { return }
        releaseAssertion()
        isHolding = false
        if isSleepDisabled {
            setDisableSleep(false)
        }
    }

    func update(preventSleepWhenLidClosed: Bool) {
        guard isHolding else { return }
        releaseAssertion()
        createAssertion(preventSleepWhenLidClosed: preventSleepWhenLidClosed)
        setDisableSleep(preventSleepWhenLidClosed)
    }

    // MARK: - IOKit

    private func createAssertion(preventSleepWhenLidClosed: Bool) {
        let reason = "Caffeine 正在阻止 Mac 休眠" as CFString
        let type = preventSleepWhenLidClosed
            ? kIOPMAssertionTypePreventSystemSleep
            : kIOPMAssertionTypePreventUserIdleDisplaySleep

        var id = IOPMAssertionID(0)
        if IOPMAssertionCreateWithName(type as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        reason, &id) == kIOReturnSuccess {
            assertionID = id
            hasAssertion = true
        }
    }

    private func releaseAssertion() {
        if hasAssertion {
            IOPMAssertionRelease(assertionID)
            hasAssertion = false
        }
    }

    // MARK: - pmset（通过特权 Helper）

    private func setDisableSleep(_ disabled: Bool) {
        guard disabled != isSleepDisabled else { return }

        Task { [weak self] in
            do {
                try await self?.helper.setSleepDisabled(disabled)
                self?.isSleepDisabled = disabled
                self?.needsApproval = false
                NSLog("[Caffeine] ✓ pmset disablesleep \(disabled ? "1" : "0")")
            } catch let error as PowerHelperError {
                if case .requiresApproval = error {
                    self?.needsApproval = true
                    NSLog("[Caffeine] ⚠ Helper 需要用户在系统设置中批准")
                } else {
                    self?.needsApproval = false
                    NSLog("[Caffeine] ✗ pmset 失败: \(error.localizedDescription)")
                }
            } catch {
                self?.needsApproval = false
                NSLog("[Caffeine] ✗ pmset 失败: \(error.localizedDescription)")
            }
        }
    }

    /// 打开系统设置以便用户批准 Helper。
    func openApprovalSettings() {
        helper.openHelperApprovalSettings()
    }
}
