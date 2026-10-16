import SwiftUI

/// 列表中的一行：勾选框 + 名称 + 截止时间（短格式）+ 悬停删除。
/// 鼠标悬停显示 tooltip：名称 / 截止时间 / 对接人 / 新增时间。
struct TodoRowView: View {
    @EnvironmentObject private var store: TodoStore
    let todo: Todo
    var onEdit: (Todo) -> Void

    @State private var isHovering = false

    private var deadlineState: DeadlineState {
        guard !todo.done, let deadline = todo.deadline else { return .none }
        if deadline < Date() { return .overdue }
        if Calendar.current.isDateInToday(deadline) { return .today }
        return .normal
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggleDone(todo.id)
            } label: {
                Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(todo.done ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(.tint))
            }
            .buttonStyle(.plain)
            .help(todo.done ? "标记为未完成" : "标记为完成")

            Text(todo.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .strikethrough(todo.done)
                .foregroundStyle(titleColor)

            Spacer(minLength: 4)

            if let deadline = todo.deadline {
                Text(Formatters.shortDateTime.string(from: deadline))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(deadlineColor)
            }

            if isHovering {
                Button {
                    store.delete(todo.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("删除")
            }

            if isHovering {
                Button {
                    onEdit(todo)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("编辑")
            }
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .background(isHovering ? Color.primary.opacity(0.06) : Color.clear)
        .help(tooltip)
        .onHover { isHovering = $0 }
    }

    // MARK: - 颜色

    private var titleColor: Color {
        if todo.done { return .secondary }
        return deadlineState == .overdue ? .red : .primary
    }

    private var deadlineColor: Color {
        switch deadlineState {
        case .overdue: return .red
        case .today: return .orange
        default: return .secondary
        }
    }

    // MARK: - 悬停详情

    private var tooltip: String {
        var lines = ["名称：\(todo.title)"]
        if !todo.notes.isEmpty {
            lines.append("明细：\(todo.notes)")
        }
        if let deadline = todo.deadline {
            lines.append("截止时间：\(Formatters.fullDateTime.string(from: deadline))")
        } else {
            lines.append("截止时间：未设置")
        }
        lines.append("对接人：\(todo.contact.isEmpty ? "未填写" : todo.contact)")
        lines.append("新增时间：\(Formatters.fullDateTime.string(from: todo.createdAt))")
        lines.append(todo.done ? "状态：已完成" : "状态：待办")
        return lines.joined(separator: "\n")
    }
}

private enum DeadlineState {
    case none, normal, today, overdue
}
