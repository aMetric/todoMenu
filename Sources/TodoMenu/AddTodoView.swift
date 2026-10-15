import SwiftUI

/// 新增待办表单：名称（必填）、截止时间（可留空）、对接人（选填）。
/// 新增时间由系统自动记录，无需填写。
struct AddTodoView: View {
    @EnvironmentObject private var store: TodoStore
    var onDone: () -> Void

    @State private var title = ""
    @State private var contact = ""
    @State private var hasDeadline = false
    @State private var deadline = AddTodoView.defaultDeadline()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("新增待办")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("名称（必填）", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            Toggle(isOn: $hasDeadline) {
                Text("设置截止时间")
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)

            if hasDeadline {
                DatePicker(
                    "截止时间",
                    selection: $deadline,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }

            TextField("对接人（选填）", text: $contact)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            Text("新增时间由系统自动记录")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            HStack {
                Spacer()
                Button("取消", action: onDone)
                Button("添加") {
                    store.add(
                        title: title,
                        deadline: hasDeadline ? deadline : nil,
                        contact: contact
                    )
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedTitle.isEmpty)
            }
        }
        .padding(12)
        .onChange(of: hasDeadline) { _, _ in
            // 截止时间开关影响表单高度，通知外壳同步弹层大小
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .popoverSizeDidChange, object: nil)
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 默认截止时间：明天 18:00
    static func defaultDeadline() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
