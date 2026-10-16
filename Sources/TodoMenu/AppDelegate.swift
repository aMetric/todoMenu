import AppKit
import CoreGraphics
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
        if Shot.outputPath != nil {
            // 截图模式同样使用临时数据文件
            return TodoStore(fileURL: Shot.dataURL)
        }
        return TodoStore()
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if SelfTest.isEnabled {
            // 清掉上次自测遗留的数据文件，保证测试确定性
            try? FileManager.default.removeItem(at: SelfTest.dataURL)
        }
        if Shot.outputPath != nil {
            try? FileManager.default.removeItem(at: Shot.dataURL)
        }
        setupStatusItem()
        setupPopover()
        // 内容变化时（表单开合、增删改查、搜索过滤）同步弹层尺寸
        sizeObserver = NotificationCenter.default.addObserver(
            forName: .popoverSizeDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.syncPopoverSize()
        }
        if let shotPath = Shot.outputPath {
            runShotIfNeeded(shotPath)
        } else {
            runSelfTestIfNeeded()
        }
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

    /// 延时执行
    private func step(_ delay: TimeInterval, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }

    /// 模拟真实操作：打开弹层 → 展开新增表单 → 添加 → 收起表单，循环多轮，
    /// 覆盖弹层内容高度变化的各种时序，验证不会崩溃。
    private func runSelfTestIfNeeded() {
        guard SelfTest.isEnabled else { return }

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
            if round == 0 {
                // 打开明细输入：表单多出 TextEditor，验证弹层尺寸同步
                step(base + 0.2) {
                    NotificationCenter.default.post(name: SelfTest.toggleNotes, object: nil)
                }
            }
            step(base + 0.4) { [weak self] in
                print("SIZE 表单展开 #\(round) = \(self?.popover?.contentSize.height ?? -1)")
            }
            step(base + 0.5) { [weak self] in
                self?.store.add(
                    title: "selftest-\(round)",
                    notes: round == 0 ? "要点一\n要点二" : "",
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

        step(6.8) { [weak self] in
            guard let self else { exit(1) }
            var ok = true

            // ① rank 档位：固定参考时钟（今天正午）逐项断言
            let cal = Calendar.current
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
            func d(_ hours: Double) -> Date { noon.addingTimeInterval(hours * 3600) }
            let rankCases: [(Date?, Bool, Int, String)] = [
                (d(-1), false, 0, "逾期"),
                (d(6), false, 1, "今天到期"),
                (d(30), false, 2, "未来"),
                (nil, false, 3, "无期限"),
                (d(-1), true, 4, "已完成（逾期期限也应压底）"),
            ]
            for (deadline, done, want, name) in rankCases {
                let todo = Todo(title: name, deadline: deadline, done: done)
                let got = todo.rank(now: noon)
                if got != want {
                    print("SORT FAIL: \(name) rank=\(got) want=\(want)")
                    ok = false
                }
            }

            // ② filtered() 排序接线：真实 store 按紧急度输出
            for t in self.store.todos { self.store.delete(t.id) }
            let now = Date()
            self.store.add(title: "逾期A", notes: "", deadline: now.addingTimeInterval(-3600), contact: "")
            self.store.add(title: "无期限B", notes: "", deadline: nil, contact: "")
            self.store.add(title: "未来C", notes: "", deadline: now.addingTimeInterval(48 * 3600), contact: "")
            let expected = ["逾期A", "未来C", "无期限B"]
            let actual = self.store.filtered("").map(\.title)
            if actual != expected {
                print("SORT FAIL: order=\(actual) want=\(expected)")
                ok = false
            }
            // 完成后沉底
            if let first = self.store.filtered("").first {
                self.store.toggleDone(first.id)
            }
            let afterDone = self.store.filtered("").map(\.title)
            if afterDone != ["未来C", "无期限B", "逾期A"] {
                print("SORT FAIL: done-last order=\(afterDone)")
                ok = false
            }
            if ok {
                print("SORT OK")
            } else {
                exit(1)
            }
        }

        step(7.5) { [weak self] in
            guard let self else { exit(1) }
            let distinct = Set(selftestHeights.map { Int($0) })
            let spread = (selftestHeights.max() ?? 0) - (selftestHeights.min() ?? 0)
            print("SELFTEST heights=\(distinct.sorted())")
            // 弹层高度必须随内容变化：至少出现 2 种取值，且跨度 ≥ 100pt
            //（表单展开约 470pt、收起约 100~280pt）。若高度恒定说明尺寸同步失效。
            if distinct.count >= 2, spread >= 100 {
                print("SELFTEST OK")
                exit(0)
            } else {
                print("SELFTEST FAIL: 弹层高度没有随内容变化（heights=\(distinct.sorted())）")
                exit(1)
            }
        }
        step(20.0) {
            print("SELFTEST TIMEOUT")
            exit(2)
        }
    }

    // MARK: - 截图模式（--shot <输出路径>）

    /// 用示例数据打开弹层并截取面板窗口，用于生成 README 截图。
    /// 与真实数据完全隔离；应用捕获自己的窗口，无需屏幕录制权限。
    private func runShotIfNeeded(_ outputPath: String) {
        let cal = Calendar.current
        let now = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let today18 = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrow10 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow

        store.add(title: "评审团队 PR", notes: "", deadline: nil, contact: "赵六")
        store.add(
            title: "和设计对齐新图标",
            notes: "领导点评：整体偏重，图标线宽降一档，状态色只用红/橙",
            deadline: tomorrow10,
            contact: "李四"
        )
        store.add(title: "写周报", notes: "", deadline: today18, contact: "张三")
        store.add(title: "提交报销单", notes: "", deadline: yesterday, contact: "王五")
        store.add(title: "整理项目 Roadmap", notes: "", deadline: nil, contact: "")
        if let last = store.todos.last {
            store.toggleDone(last.id) // 展示已完成样式
        }

        step(0.6) { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.togglePopover(nil)
        }
        step(1.8) { [weak self] in
            self?.captureShot(to: outputPath)
        }
    }

    private func captureShot(to path: String) {
        guard let window = popover?.contentViewController?.view.window else {
            print("SHOT FAIL: window not found")
            exit(1)
        }
        guard
            let image = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                CGWindowID(window.windowNumber),
                [.boundsIgnoreFraming]
            )
        else {
            print("SHOT FAIL: capture failed")
            exit(1)
        }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            print("SHOT FAIL: png encode failed")
            exit(1)
        }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            print("SHOT OK: \(path)")
            exit(0)
        } catch {
            print("SHOT FAIL: \(error)")
            exit(1)
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
    static let toggleNotes = Notification.Name("todoMenu.selftest.toggleNotes")
}

/// 截图模式常量（--shot <输出路径>）
enum Shot {
    static var outputPath: String? {
        guard let i = CommandLine.arguments.firstIndex(of: "--shot"),
              i + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[i + 1]
    }

    static let dataURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("todomenu-shot.json")
}

extension Notification.Name {
    /// 弹层内容发生变化，需要重新计算尺寸
    static let popoverSizeDidChange = Notification.Name("todoMenu.popoverSizeDidChange")
}
