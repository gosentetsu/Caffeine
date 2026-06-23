//
//  caffeineApp.swift
//  caffeine
//
//  Created on 2026/6/23.
//

import SwiftUI

@main
struct caffeineApp: App {
    // 使用 AppKit 的 NSStatusItem 自行处理左/右键，故通过 AppDelegate 承载主要逻辑。
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 菜单栏常驻 App（LSUIElement）无主窗口，这里用空的 Settings 场景占位。
        Settings {
            EmptyView()
        }
    }
}
