import Foundation
import Combine

/// 待办数据仓库：内存态 + 本地 JSON 文件持久化。
/// 数据文件：~/Library/Application Support/TodoMenu/todos.json
final class TodoStore: ObservableObject {
    @Published private(set) var todos: [Todo] = []
    /// 最近一次破坏性操作（删除/完成切换）前的列表快照，供撤销
    @Published private(set) var lastSnapshot: [Todo]?

    private let fileURL: URL
    private static let currentVersion = 1

    /// 磁盘文件结构（带版本号，便于后续迁移）
    private struct TodoFile: Codable {
        var version: Int
        var todos: [Todo]
    }

    /// - Parameter fileURL: 自定义数据文件路径。默认使用 Application Support 下的
    ///   `TodoMenu/todos.json`；自测模式传临时路径，避免污染真实数据。
    init(fileURL: URL? = nil) {
        let url: URL
        if let fileURL {
            try? FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            url = fileURL
        } else {
            let supportDir = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            let dir = supportDir.appendingPathComponent("TodoMenu", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("todos.json")
        }
        self.fileURL = url
        load()
    }

    /// 未完成数量（面板底部展示）
    var activeCount: Int { todos.filter { !$0.done }.count }

    /// 撤销条文案
    var deletedLabel: String {
        guard let snapshot = lastSnapshot else { return "" }
        let removed = snapshot.filter { old in todos.first { $0.id == old.id } == nil }
        if !removed.isEmpty {
            return "已删除「\(removed.first?.title ?? "")」"
        }
        let toggled = snapshot.filter { old in
            todos.first { $0.id == old.id }?.done != old.done
        }
        if !toggled.isEmpty {
            return "已\(toggled.first?.done == true ? "恢复" : "完成")「\(toggled.first?.title ?? "")」"
        }
        return "已修改"
    }

    /// 撤销条过期：清掉快照（不改变 todos）
    func expireUndo() {
        lastSnapshot = nil
    }

    /// 逾期未完成数量（底部展示：N 条待办，M 条逾期）
    var overdueCount: Int {
        let now = Date()
        return todos.filter { !$0.done && $0.deadline.map { $0 < now } == true }.count
    }

    /// 按搜索词过滤（匹配名称、明细与对接人，不区分大小写）。
    /// 排序（紧急度优先）：逾期 > 今天到期 > 未来有截止时间 > 无截止时间 > 已完成，
    /// 同档内新的在前。用户点开面板想知道的是"现在最该做哪个"。
    func filtered(_ query: String) -> [Todo] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = q.isEmpty
            ? todos
            : todos.filter {
                $0.title.localizedCaseInsensitiveContains(q)
                    || $0.notes.localizedCaseInsensitiveContains(q)
                    || $0.contact.localizedCaseInsensitiveContains(q)
            }
        let now = Date()
        return base.sorted { a, b in
            let ra = a.rank(now: now)
            let rb = b.rank(now: now)
            if ra != rb { return ra < rb }
            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    func add(title: String, notes: String, deadline: Date?, contact: String) {
        let todo = Todo(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes,
            deadline: deadline,
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        todos.append(todo)
        save()
    }

    /// 编辑待办（按 id 更新，保留 createdAt 不变）
    func update(
        _ id: UUID,
        title: String,
        notes: String,
        deadline: Date?,
        contact: String
    ) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        todos[i].notes = notes
        todos[i].deadline = deadline
        todos[i].contact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func toggleDone(_ id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        lastSnapshot = todos
        todos[i].done.toggle()
        save()
    }

    func delete(_ id: UUID) {
        lastSnapshot = todos
        todos.removeAll { $0.id == id }
        save()
    }

    /// 撤销最近一次删除/完成操作（快照恢复，快照清空）
    func undo() {
        guard let snapshot = lastSnapshot else { return }
        todos = snapshot
        lastSnapshot = nil
        save()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let file = try decoder.decode(TodoFile.self, from: data)
            todos = file.todos
        } catch {
            // 数据损坏：备份原文件后从空列表重新开始，避免应用打不开
            let backup = fileURL.appendingPathExtension("bak-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            todos = []
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(TodoFile(version: Self.currentVersion, todos: todos)) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
        // 通知外壳（菜单栏计数）数据已变化
        NotificationCenter.default.post(name: .todosDidChange, object: nil)
    }
}
