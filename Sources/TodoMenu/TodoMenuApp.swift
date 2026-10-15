import AppKit
import SwiftUI

/// 应用入口：纯菜单栏应用，无 Dock 图标、无主窗口。
@main
struct TodoMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TodoStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(store)
        } label: {
            Text("TODO")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // accessory 模式：`swift run` 调试时也不显示 Dock 图标，
        // 与打包后的 .app 行为一致（.app 里另有 LSUIElement 兜底）。
        NSApp.setActivationPolicy(.accessory)
    }
}
