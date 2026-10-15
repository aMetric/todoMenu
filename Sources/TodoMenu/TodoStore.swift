import Foundation
import Combine

/// 待办数据仓库：内存态 + 本地 JSON 文件持久化。
/// 数据文件：~/Library/Application Support/TodoMenu/todos.json
final class TodoStore: ObservableObject {
    @Published private(set) var todos: [Todo] = []

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

    /// 按搜索词过滤（匹配名称与对接人，不区分大小写）。
    /// 排序：未完成在前（新的在前），已完成在后。
    func filtered(_ query: String) -> [Todo] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = q.isEmpty
            ? todos
            : todos.filter {
                $0.title.localizedCaseInsensitiveContains(q)
                    || $0.contact.localizedCaseInsensitiveContains(q)
            }
        return base.sorted { a, b in
            if a.done != b.done { return !a.done }
            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    func add(title: String, deadline: Date?, contact: String) {
        let todo = Todo(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            deadline: deadline,
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        todos.append(todo)
        save()
    }

    func toggleDone(_ id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].done.toggle()
        save()
    }

    func delete(_ id: UUID) {
        todos.removeAll { $0.id == id }
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
    }
}
