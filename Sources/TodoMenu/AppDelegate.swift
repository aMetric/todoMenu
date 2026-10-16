import AppKit
import CoreGraphics
import CoreText
import SwiftUI

/// 应用外壳：NSStatusItem（菜单栏 "TODO" 文字图标）+ NSPopover（承载 SwiftUI 内容）。
/// 弃用 MenuBarExtra(.window)：弹层内容高度变化时 macOS 会抛 AppKit 约束异常导致应用退出。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hosting: NSHostingController<AnyView>?
    private var sizeObserver: NSObjectProtocol?
    private var selftestHeights: [CGFloat] = []
    private var editingTarget: Todo?

    /// 菜单栏图标：SF Symbols 模板图标（自动适配明暗模式）。
    /// 想换风格改这一个常量即可，候选见 README。
    static let menubarSymbol = "checkmark.circle"

    private lazy var store: TodoStore = {
        if SelfTest.isEnabled {
            // 自测模式使用临时数据文件，不污染真实数据
            return TodoStore(fileURL: SelfTest.dataURL)
        }
        if Shot.isActive {
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
        if Shot.isActive {
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
        if let shot = Shot.scene {
            runShotIfNeeded(shot)
        } else if LaunchAtLoginCLI.isEnabled {
            // 维护参数：切换开机自启注册后立即退出（供安装脚本/终端验证用）
            let newState = LaunchAtLogin.toggle()
            print("AUTOLAUNCH \(newState ? "ON" : "OFF")")
            NSApp.terminate(nil)
        } else {
            runSelfTestIfNeeded()
        }
    }

    // MARK: - 菜单栏图标

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            // 模板图标：自动适配亮/暗菜单栏，与系统图标观感一致
            let icon = NSImage(
                systemSymbolName: Self.menubarSymbol,
                accessibilityDescription: "TodoMenu"
            )
            icon?.isTemplate = true
            button.image = icon
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

        // 编辑流：对列表第一行打开编辑表单 → 改标题与截止 → 保存 → 校验
        step(6.2) { [weak self] in
            guard let first = self?.store.filtered("").first else { return }
            self?.editingTarget = first
            NotificationCenter.default.post(name: SelfTest.editFirstRow, object: first)
        }
        step(6.5) { [weak self] in
            print("SIZE 编辑表单 = \(self?.popover?.contentSize.height ?? -1)")
        }
        step(6.6) {
            NotificationCenter.default.post(
                name: SelfTest.setFormTitle, object: "编辑后的标题"
            )
            NotificationCenter.default.post(
                name: SelfTest.toggleDeadline, object: nil
            )
        }
        step(6.7) {
            NotificationCenter.default.post(name: SelfTest.saveForm, object: nil)
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

            // ② 编辑流：第一行被 update 改了标题与期限，createdAt 不变、不产生新条目
            if let before = self.editingTarget {
                let beforeCount = self.store.todos.count
                let after = self.store.todos.first { $0.id == before.id }
                if after == nil || after?.title != "编辑后的标题" || after?.deadline == nil {
                    print("EDIT FAIL: \(String(describing: after?.title)) deadline=\(String(describing: after?.deadline))")
                    ok = false
                }
                if after?.createdAt != before.createdAt {
                    print("EDIT FAIL: createdAt 被篡改")
                    ok = false
                }
                if self.store.todos.count != beforeCount {
                    print("EDIT FAIL: 编辑产生了新条目")
                    ok = false
                }
            } else {
                print("EDIT FAIL: 编辑目标未设置")
                ok = false
            }

            // ③ filtered() 排序接线：真实 store 按紧急度输出
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

            // ④ 撤销流：删除一条 → 快照存在且文案正确 → undo 恢复
            let victim = self.store.filtered("").first!
            self.store.delete(victim.id)
            if self.store.lastSnapshot == nil {
                print("UNDO FAIL: 删除后无快照")
                ok = false
            }
            if self.store.filtered("").contains(where: { $0.id == victim.id }) {
                print("UNDO FAIL: 删除未生效")
                ok = false
            }
            let label = self.store.deletedLabel
            if !label.contains(victim.title) || !label.contains("已删除") {
                print("UNDO FAIL: label=\(label)")
                ok = false
            }
            self.store.undo()
            if !self.store.todos.contains(where: { $0.id == victim.id }) {
                print("UNDO FAIL: 撤销未恢复")
                ok = false
            }
            if self.store.lastSnapshot != nil {
                print("UNDO FAIL: 撤销后快照未清空")
                ok = false
            }

            // ⑤ 菜单栏图标：SF Symbols 模板图标常量（结构校验，title 断言已随数字移除）
            if AppDelegate.menubarSymbol.isEmpty {
                print("TITLE FAIL: menubarSymbol 未配置")
                ok = false
            }
            if self.statusItem?.button?.image == nil {
                print("TITLE FAIL: 菜单栏未设置图标")
                ok = false
            }

            // ⑥ 自启开关（mock）：翻转 → 状态生效，再翻回避免污染后续
            UserDefaults.standard.removeObject(forKey: SelfTest.mockAutoLaunchKey)
            if LaunchAtLogin.isEnabled != false {
                print("AUTOLAUNCH FAIL: mock 初始态应为 false")
                ok = false
            }
            LaunchAtLogin.toggle()
            if LaunchAtLogin.isEnabled != true {
                print("AUTOLAUNCH FAIL: 翻转后应为 true")
                ok = false
            }
            LaunchAtLogin.toggle()
            if LaunchAtLogin.isEnabled != false {
                print("AUTOLAUNCH FAIL: 回翻后应为 false")
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
    /// 场景：panel（列表+悬停）/ form（新增表单）/ edit（编辑表单）/ undo（撤销条）/ empty（空状态）
    private func runShotIfNeeded(_ scene: Shot.Scene) {
        seedShotData(scene.name)

        step(0.6) { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.togglePopover(nil)
        }
        // 场景准备：表单/编辑/撤销在弹层打开后再触发
        step(1.0) { [weak self] in
            guard let self else { return }
            switch scene.name {
            case "form":
                NotificationCenter.default.post(name: SelfTest.openForm, object: nil)
            case "edit":
                if let first = store.filtered("").first {
                    NotificationCenter.default.post(
                        name: SelfTest.editFirstRow, object: first
                    )
                }
            case "undo":
                if let first = store.filtered("").first {
                    store.delete(first.id) // 底部出现撤销条
                }
            case "empty":
                for t in store.todos { store.delete(t.id) }
            default:
                break
            }
        }
        step(1.8) { [weak self] in
            self?.captureShot(to: scene.path, composeMenubar: scene.name == "panel")
        }
    }

    /// 各场景的示例数据
    private func seedShotData(_ scene: String) {
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
    }

    /// 截取弹层窗口；panel 场景额外合成一段菜单栏场景（含 TODO 图标）
    private func captureShot(to path: String, composeMenubar: Bool) {
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
        var finalImage = image
        if composeMenubar {
            finalImage = Self.composePanelWithMenubar(panel: image)
        }
        let rep = NSBitmapImageRep(cgImage: finalImage)
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

    /// 主截图合成：弹层左上角对齐，上方拼一条仿菜单栏（含 SF Symbols 图标、时间、
    /// 深浅渐变壁纸底色），让"菜单栏应用"的使用场景一眼可读
    static func composePanelWithMenubar(panel: CGImage) -> CGImage {
        let scale: CGFloat = 2
        let menubarH: CGFloat = 24
        let padLeading: CGFloat = 16
        let padTop: CGFloat = 12
        let padTrailing: CGFloat = 24
        let padBottom: CGFloat = 24

        let panelW = CGFloat(panel.width) / scale
        let panelH = CGFloat(panel.height) / scale
        let canvasW = panelW + padLeading + padTrailing
        let canvasH = menubarH + padTop + panelH + padBottom

        // macOS 菜单栏渐变壁纸底色（近似 Sonoma 深蓝）
        let colors = [
            CGColor(red: 0.16, green: 0.18, blue: 0.26, alpha: 1),
            CGColor(red: 0.22, green: 0.24, blue: 0.34, alpha: 1),
        ]
        let canvasWpx = Int(canvasW * scale)
        let canvasHpx = Int(canvasH * scale)
        guard let ctx = CGContext(
            data: nil,
            width: canvasWpx,
            height: canvasHpx,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return panel }

        // 背景：顶部深、往下渐浅的壁纸感
        let bg = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(
            bg,
            start: CGPoint(x: 0, y: CGFloat(canvasHpx)),
            end: CGPoint(x: 0, y: 0),
            options: []
        )

        // 菜单栏：图标 + 菜单文字 + 时间，白色 85%
        let icon = NSImage(systemSymbolName: AppDelegate.menubarSymbol, accessibilityDescription: nil)
        icon?.isTemplate = true
        let iconSize: CGFloat = 15
        let iconX = padLeading + 10
        let iconY = (menubarH - iconSize) / 2
        if let icon,
           let iconCG = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            // 模板图标是黑色，画白色：用 NSImage 绘制 + sourceAtop 太繁琐，
            // 直接以普通方式绘制（浅底图标在深底上不可见），改用白色 tint：
            let tinted = Self.tintCGImage(iconCG, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
            ctx.draw(
                tinted,
                in: CGRect(x: iconX * scale, y: (canvasH - iconY - iconSize) * scale, width: iconSize * scale, height: iconSize * scale)
            )
        }

        // 菜单栏右侧时间（CoreText 直画，避免 NSGraphicsContext 依赖）
        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.92),
        ]
        let timeStr = NSAttributedString(string: "10月16日 周四 12:34", attributes: timeAttrs)
        let timeSize = timeStr.size()
        let timeX = canvasW - padTrailing - timeSize.width
        let timeY = (menubarH - timeSize.height) / 2
        // CoreText 坐标原点左下、y 向上：文字基线放进菜单栏条（顶部 menubarH pt）
        let line = CTLineCreateWithAttributedString(timeStr)
        ctx.textPosition = CGPoint(
            x: timeX * scale,
            y: (canvasH - timeSize.height - (menubarH - timeSize.height) / 2) * scale
        )
        CTLineDraw(line, ctx)

        // 淡描边：让弹层在深色底上更"浮"
        // CGContext 坐标原点在左下；NSImage/NSAttributedString 绘制原点在左下（ flipped 无关）
        // 弹层：CGImage 直接绘制
        let panelRect = CGRect(
            x: padLeading * scale,
            y: padBottom * scale,
            width: panelW * scale,
            height: panelH * scale
        )
        // 阴影
        ctx.setShadow(
            offset: CGSize(width: 0, height: -6),
            blur: 18,
            color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45)
        )
        ctx.draw(panel, in: panelRect)
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        guard let out = ctx.makeImage() else { return panel }
        return out
    }

    /// CGImage 纯色 tint：重绘像素
    static func tintCGImage(_ image: CGImage, color: CGColor) -> CGImage {
        let w = image.width
        let h = image.height
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        // sourceAtop 覆盖颜色
        ctx.setBlendMode(.sourceAtop)
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
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
    static let editFirstRow = Notification.Name("todoMenu.selftest.editFirstRow")
    static let setFormTitle = Notification.Name("todoMenu.selftest.setFormTitle")
    static let toggleDeadline = Notification.Name("todoMenu.selftest.toggleDeadline")
    static let saveForm = Notification.Name("todoMenu.selftest.saveForm")
    static let toggleAutoLaunch = Notification.Name("todoMenu.selftest.toggleAutoLaunch")

    /// selftest 下自启开关的 mock 存储 key（CI 无头环境不动真实登录项）
    static let mockAutoLaunchKey = "todoMenu.selftest.autoLaunchMock"
}

/// 截图模式常量（--shot <场景>=<输出路径>；不带的场景默认 panel）
/// 场景：panel 主面板（合成菜单栏）/ form 新增表单 / edit 编辑 / undo 撤销条 / empty 空状态
enum Shot {
    struct Scene {
        let name: String
        let path: String
    }

    static var rawArg: String? {
        guard let i = CommandLine.arguments.firstIndex(of: "--shot"),
              i + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[i + 1]
    }

    static var isActive: Bool { rawArg != nil }

    static var scene: Scene? {
        guard let raw = rawArg else { return nil }
        if let eq = raw.firstIndex(of: "=") {
            return Scene(name: String(raw[..<eq]), path: String(raw[raw.index(after: eq)...]))
        }
        return Scene(name: "panel", path: raw)
    }

    static let dataURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("todomenu-shot.json")
}

/// 维护参数常量（--toggle-autalaunch：切换开机自启后退出）
enum LaunchAtLoginCLI {
    static var isEnabled: Bool {
        CommandLine.arguments.contains("--toggle-autalaunch")
    }
}

extension Notification.Name {
    /// 弹层内容发生变化，需要重新计算尺寸
    static let popoverSizeDidChange = Notification.Name("todoMenu.popoverSizeDidChange")

    /// 待办数据已持久化（菜单栏计数等外壳元素跟随刷新）
    static let todosDidChange = Notification.Name("todoMenu.todosDidChange")
}
