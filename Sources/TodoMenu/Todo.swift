import Foundation

/// 一条待办事项
struct Todo: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String      // 名称（必填）
    var deadline: Date?    // 截止时间（可空）
    var contact: String    // 对接人（可空）
    var createdAt: Date    // 新增时间（系统自动记录）
    var done: Bool         // 是否已完成

    init(
        id: UUID = UUID(),
        title: String,
        deadline: Date? = nil,
        contact: String = "",
        createdAt: Date = Date(),
        done: Bool = false
    ) {
        self.id = id
        self.title = title
        self.deadline = deadline
        self.contact = contact
        self.createdAt = createdAt
        self.done = done
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
