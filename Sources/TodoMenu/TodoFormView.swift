import SwiftUI

/// 新增 / 编辑待办表单：名称（必填）、明细（选填，多行）、截止时间（可留空）、对接人（选填）。
/// 新增时间由系统自动记录，无需填写；编辑时保持原新增时间不变。
struct TodoFormView: View {
    @EnvironmentObject private var store: TodoStore
    var editing: Todo?
    var focusTitle: FocusState<Bool>.Binding
    var onDone: () -> Void

    @State private var title = ""
    @State private var contact = ""
    @State private var hasNotes = false
    @State private var notes = ""
    @State private var hasDeadline = false
    @State private var deadline = TodoFormView.defaultDeadline()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(editing == nil ? "新增待办" : "编辑待办")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("名称（必填）", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .focused(focusTitle)

            Toggle(isOn: $hasNotes) {
                Text("添加明细")
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)

            if hasNotes {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $notes)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color(nsColor: .controlBackgroundColor),
                                              lineWidth: 1)
                        )
                        .frame(height: 62)
                    if notes.isEmpty {
                        Text("记录要点 / 原话，可多行…")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 7)
                            .allowsHitTesting(false)
                    }
                }
            }

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
                    .keyboardShortcut(.cancelAction) // Esc 收起表单
                Button(editing == nil ? "添加" : "保存") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedTitle.isEmpty)
            }
        }
        .padding(12)
        .onAppear {
            if let editing {
                title = editing.title
                contact = editing.contact
                notes = editing.notes
                hasNotes = !editing.notes.isEmpty
                hasDeadline = editing.deadline != nil
                deadline = editing.deadline ?? TodoFormView.defaultDeadline()
            }
            // 表单打开即聚焦标题（Enter 保存，Esc 收起），秒记不打断
            DispatchQueue.main.async {
                focusTitle.wrappedValue = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: SelfTest.toggleNotes)) { _ in
            guard SelfTest.isEnabled else { return }
            hasNotes.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: SelfTest.saveForm)) { _ in
            guard SelfTest.isEnabled else { return }
            submit()
        }
        .onReceive(NotificationCenter.default.publisher(for: SelfTest.setFormTitle)) { note in
            guard SelfTest.isEnabled, let newTitle = note.object as? String else { return }
            title = newTitle
        }
        .onReceive(NotificationCenter.default.publisher(for: SelfTest.toggleDeadline)) { _ in
            guard SelfTest.isEnabled else { return }
            hasDeadline = true
        }
        .onChange(of: hasNotes) { _, _ in
            // 明细开关影响表单高度，通知外壳同步弹层大小
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .popoverSizeDidChange, object: nil)
            }
        }
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

    /// 提交表单：编辑则更新原条目（保持 createdAt 不变），否则新增
    private func submit() {
        if let editing {
            store.update(
                editing.id,
                title: title,
                notes: hasNotes ? notes : "",
                deadline: hasDeadline ? deadline : nil,
                contact: contact
            )
        } else {
            store.add(
                title: title,
                notes: hasNotes ? notes : "",
                deadline: hasDeadline ? deadline : nil,
                contact: contact
            )
        }
        onDone()
    }

    /// 默认截止时间：明天 18:00
    static func defaultDeadline() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
