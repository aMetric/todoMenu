import AppKit

// 纯 AppKit 启动，不使用 SwiftUI App / MenuBarExtra。
// 原因：macOS 14+ 的 MenuBarExtra(.window) 弹层在内容高度变化时存在崩溃 bug
//（NSWindow _postWindowNeedsUpdateConstraints 抛 NSException），
// 改用传统的 NSStatusItem + NSPopover 方案，稳定且长期可维护。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
setbuf(stdout, nil) // 关闭 stdout 缓冲，保证自测输出即时可见
app.run()
