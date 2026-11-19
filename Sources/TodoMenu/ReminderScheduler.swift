import Foundation
import UserNotifications

/// 本地通知提醒：截止时间到点提醒 + 逾期补发（只发一次）+ 稍后提醒。
/// 所有调度统一走本类，selftest/截图模式下走 mock（只记录调用，不碰系统通知中心）。
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    /// 到点提醒的 identifier 前缀（sync 时整体重排）
    static let todoPrefix = "todo."
    /// 稍后提醒的 identifier 前缀（用户手动排期，sync 时不重排）
    static let snoozePrefix = "snooze."

    /// 已补发逾期通知的标记（id|deadline 时间戳），存 UserDefaults，保证只补发一次
    private static let notifiedKey = "todoMenu.overdueNotified"

    /// mock 模式：selftest / 截图模式下置 true
    var isMock = false

    /// mock 模式下本次 sync 排期的通知（sync 时清空）
    private(set) var scheduledForTest: [(id: String, date: Date?, title: String)] = []
    /// mock 模式下历史全部通知记录（不清空，用于断言"逾期只补发一次"）
    private(set) var recordedAll: [(id: String, date: Date?, title: String)] = []

    /// 请求通知权限（应用启动时调用一次；mock 模式跳过）
    func requestAuthorization() {
        guard !isMock else { return }
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    /// 待办数据变化后重排到点提醒：删掉旧排期，按当前数据重建。
    /// 逾期且未完成的待办立即补发一条（每条只发一次，标记持久化）。
    func sync(todos: [Todo]) {
        if isMock {
            scheduledForTest.removeAll()
            rebuild(todos: todos)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.todoPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            DispatchQueue.main.async { self.rebuild(todos: todos) }
        }
    }

    private func rebuild(todos: [Todo]) {
        let now = Date()
        var notified = Set(UserDefaults.standard.stringArray(forKey: Self.notifiedKey) ?? [])

        for todo in todos where !todo.done {
            guard let deadline = todo.deadline else { continue }
            let key = "\(todo.id.uuidString)|\(Int(deadline.timeIntervalSince1970))"
            if deadline <= now {
                // 逾期补发：只发一次
                if !notified.contains(key) {
                    notify(
                        id: Self.todoPrefix + todo.id.uuidString,
                        date: nil,
                        title: "逾期：\(todo.title)",
                        body: body(of: todo, deadline: deadline)
                    )
                    notified.insert(key)
                }
            } else {
                notify(
                    id: Self.todoPrefix + todo.id.uuidString,
                    date: deadline,
                    title: "到点：\(todo.title)",
                    body: body(of: todo, deadline: deadline)
                )
            }
        }

        UserDefaults.standard.set(Array(notified), forKey: Self.notifiedKey)
    }

    /// 稍后提醒：为待办在指定时间排一条一次性通知
    func snooze(todo: Todo, at date: Date) {
        notify(
            id: Self.snoozePrefix + todo.id.uuidString + "|\(Int(date.timeIntervalSince1970))",
            date: date,
            title: "稍后提醒：\(todo.title)",
            body: body(of: todo, deadline: todo.deadline)
        )
    }

    /// 明天上午 9:00
    static func tomorrowNineOClock(now: Date = Date()) -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
            ?? tomorrow
    }

    // MARK: - 内部

    private func body(of todo: Todo, deadline: Date?) -> String {
        var lines: [String] = []
        if let deadline {
            lines.append("截止：\(Formatters.fullDateTime.string(from: deadline))")
        }
        if !todo.contact.isEmpty {
            lines.append("对接人：\(todo.contact)")
        }
        if let firstLine = todo.notes.split(separator: "\n").first, !firstLine.isEmpty {
            lines.append(String(firstLine))
        }
        return lines.joined(separator: "\n")
    }

    private func notify(id: String, date: Date?, title: String, body: String) {
        scheduledForTest.append((id, date, title))
        recordedAll.append((id, date, title))
        guard !isMock else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = date.map {
            UNTimeIntervalNotificationTrigger(
                timeInterval: max($0.timeIntervalSinceNow, 1),
                repeats: false
            )
        }
        let request = UNNotificationRequest(
            identifier: id, content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
