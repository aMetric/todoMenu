import Foundation

/// 一条待办事项
struct Todo: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String      // 名称（必填）
    var notes: String      // 明细（选填，多行：如会议要点、领导原话）
    var deadline: Date?    // 截止时间（可空）
    var contact: String    // 对接人（可空）
    var createdAt: Date    // 新增时间（系统自动记录）
    var done: Bool         // 是否已完成

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        deadline: Date? = nil,
        contact: String = "",
        createdAt: Date = Date(),
        done: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.deadline = deadline
        self.contact = contact
        self.createdAt = createdAt
        self.done = done
    }

    // MARK: - 兼容旧数据文件

    /// v0.3 前的数据文件没有 notes 字段：解码时缺省为空串，
    /// 保证旧 todos.json 直接可用（version 仍为 1，新增字段向后兼容）。
    private enum CodingKeys: String, CodingKey {
        case id, title, notes, deadline, contact, createdAt, done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        deadline = try c.decodeIfPresent(Date.self, forKey: .deadline)
        contact = try c.decodeIfPresent(String.self, forKey: .contact) ?? ""
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        done = try c.decode(Bool.self, forKey: .done)
    }

    // MARK: - 紧急度排序

    /// 紧急度档位：数值越小越靠前。
    /// 逾期(0) > 今天到期(1) > 未来有截止时间(2) > 无截止时间(3) > 已完成(4)
    func rank(now: Date = Date()) -> Int {
        if done { return 4 }
        guard let deadline else { return 3 }
        if deadline < now { return 0 }
        if Calendar.current.isDateInToday(deadline) { return 1 }
        return 2
    }
}

/// 统一的日期格式
enum Formatters {
    /// 行内短格式：10-20 18:00
    static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    /// 悬停详情完整格式：2025-10-20 18:00
    static let fullDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}
