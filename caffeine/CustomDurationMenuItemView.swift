//
//  CustomDurationMenuItemView.swift
//  Caffeine
//
//  Created on 2026/6/23.
//

import AppKit

/// 「自定义时长」子菜单里的直接输入行。
///
/// 在文本框里直接输入分钟数，按回车即按该时长激活，无需弹窗、无需按钮。
final class CustomDurationMenuItemView: NSView {

    /// 回车确定时回调，参数为分钟数（正整数）。
    var onStart: ((Int) -> Void)?

    private let minMinutes = 1
    private let maxMinutes = 1440

    private let titleLabel = NSTextField(labelWithString: NSLocalizedString("Custom", comment: ""))
    private let minutesField = NSTextField()
    private let unitLabel = NSTextField(labelWithString: NSLocalizedString("min", comment: ""))

    /// - Parameter initialMinutes: 初始分钟数（<=0 时取默认 60）。
    init(initialMinutes: Int) {
        super.init(frame: NSRect(x: 0, y: 0, width: 186, height: 30))
        setupSubviews(minutes: initialMinutes > 0 ? initialMinutes : 60)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews(minutes: Int) {
        titleLabel.frame = NSRect(x: 14, y: 6, width: 44, height: 18)
        addSubview(titleLabel)

        // 仅允许整数，范围 1~1440 分钟。
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        formatter.minimum = NSNumber(value: minMinutes)
        formatter.maximum = NSNumber(value: maxMinutes)

        minutesField.frame = NSRect(x: 60, y: 5, width: 56, height: 21)
        minutesField.formatter = formatter
        minutesField.alignment = .center
        minutesField.integerValue = minutes
        minutesField.placeholderString = "90"
        minutesField.target = self
        minutesField.action = #selector(commit) // 回车触发
        addSubview(minutesField)

        unitLabel.frame = NSRect(x: 122, y: 6, width: 44, height: 18)
        addSubview(unitLabel)
    }

    @objc private func commit() {
        let minutes = minutesField.integerValue
        guard minutes > 0 else { return }
        // 关闭整个菜单后再回调激活。
        dismissMenu()
        onStart?(minutes)
    }

    /// 沿父级链关闭整个弹出的菜单。
    private func dismissMenu() {
        var menu = enclosingMenuItem?.menu
        while let parent = menu?.supermenu {
            menu = parent
        }
        menu?.cancelTracking()
    }
}
