import AppKit
import SwiftUI

/// 应用外壳：NSStatusItem（菜单栏 "TODO" 文字图标）+ NSPopover（承载 SwiftUI 内容）。
/// 弃用 MenuBarExtra(.window)：弹层内容高度变化时 macOS 会抛 AppKit 约束异常导致应用退出。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hosting: NSHostingController<AnyView>?
    private var sizeObserver: NSObjectProtocol?
    private var selftestHeights: [CGFloat] = []

    private lazy var store: TodoStore = {
        if SelfTest.isEnabled {
            // 自测模式使用临时数据文件，不污染真实数据
            return TodoStore(fileURL: SelfTest.dataURL)
        }
        return TodoStore()
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        // 内容变化时（表单开合、增删改查、搜索过滤）同步弹层尺寸
        sizeObserver = NotificationCenter.default.addObserver(
            forName: .popoverSizeDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.syncPopoverSize()
        }
        runSelfTestIfNeeded()
    }

    // MARK: - 菜单栏图标

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "TODO"
            button.font = NSFont.menuBarFont(ofSize: 0)
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    // MARK: - 弹层

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient // 点击面板外部自动关闭
        popover.animates = false      // 关闭弹层动画，规避尺寸变化崩溃
        let content = AnyView(
            PopoverView()
                .environmentObject(store)
                .frame(width: 340)
        )
        let hosting = NSHostingController(rootView: content)
        popover.contentViewController = hosting
        self.hosting = hosting
        self.popover = popover
    }

    /// 按 SwiftUI 内容的理想尺寸同步弹层大小（NSPopover 只会随内容增大、
    /// 不会自动缩小，需要显式用 fittingSize 双向同步）。
    private func syncPopoverSize() {
        guard let popover, popover.isShown, let hosting else { return }
        hosting.view.layoutSubtreeIfNeeded()
        let ideal = hosting.view.fittingSize
        guard ideal.height > 0 else { return }
        popover.contentSize = ideal
        if SelfTest.isEnabled {
            selftestHeights.append(ideal.height)
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            // 首次布局完成后再校准一次尺寸
            DispatchQueue.main.async { [weak self] in
                self?.syncPopoverSize()
            }
        }
    }

    // MARK: - 自测模式（--selftest）

    /// 模拟真实操作：打开弹层 → 展开新增表单 → 添加 → 收起表单，循环多轮，
    /// 覆盖弹层内容高度变化的各种时序，验证不会崩溃。
    private func runSelfTestIfNeeded() {
        guard SelfTest.isEnabled else { return }

        func step(_ delay: TimeInterval, _ action: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        }

        step(0.5) { [weak self] in
            // 先激活应用再弹层：transient 弹层在应用未激活时会自动关闭，
            // 真实用户点击状态栏图标时应用即被激活，这里模拟同样行为。
            NSApp.activate(ignoringOtherApps: true)
            self?.togglePopover(nil)
        }

        for round in 0..<3 {
            let base = 1.0 + Double(round) * 2.0
            step(base) {
                NotificationCenter.default.post(name: SelfTest.openForm, object: nil)
            }
            step(base + 0.4) { [weak self] in
                print("SIZE 表单展开 #\(round) = \(self?.popover?.contentSize.height ?? -1)")
            }
            step(base + 0.5) { [weak self] in
                self?.store.add(
                    title: "selftest-\(round)",
                    deadline: round == 1 ? Date() : nil,
                    contact: "tester"
                )
                NotificationCenter.default.post(name: SelfTest.closeForm, object: nil)
            }
            step(base + 1.0) { [weak self] in
                print("SIZE 表单收起 #\(round) = \(self?.popover?.contentSize.height ?? -1)")
                if let last = self?.store.todos.last {
                    self?.store.toggleDone(last.id)
                }
            }
        }

        step(7.5) { [weak self] in
            guard let self else { exit(1) }
            let distinct = Set(selftestHeights.map { Int($0) })
            print("SELFTEST heights=\(distinct.sorted())")
            // 弹层高度必须随内容（表单开合/列表增减）至少出现 3 种取值，
            // 证明尺寸双向同步生效；若高度恒定说明同步失效。
            if distinct.count >= 3 {
                print("SELFTEST OK")
                exit(0)
            } else {
                print("SELFTEST FAIL: 弹层高度没有随内容变化")
                exit(1)
            }
        }
        step(20.0) {
            print("SELFTEST TIMEOUT")
            exit(2)
        }
    }
}

/// 自测模式常量
enum SelfTest {
    static var isEnabled: Bool { CommandLine.arguments.contains("--selftest") }

    static let dataURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("todomenu-selftest.json")

    static let resultMarker = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("todomenu-selftest-ok")

    static let openForm = Notification.Name("todoMenu.selftest.openForm")
    static let closeForm = Notification.Name("todoMenu.selftest.closeForm")
}

extension Notification.Name {
    /// 弹层内容发生变化，需要重新计算尺寸
    static let popoverSizeDidChange = Notification.Name("todoMenu.popoverSizeDidChange")
}
