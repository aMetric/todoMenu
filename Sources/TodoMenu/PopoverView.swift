import AppKit
import SwiftUI

/// 点击菜单栏 "TODO" 后弹出的面板
struct PopoverView: View {
    @EnvironmentObject private var store: TodoStore
    @State private var searchText = ""
    @State private var showAddForm = false

    private let rowHeight: CGFloat = 44
    private let maxVisibleRows = 5

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340)
    }

    // MARK: - 顶部：搜索框 + 加号

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("搜索名称 / 对接人", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showAddForm.toggle() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .help(showAddForm ? "收起新增表单" : "新增待办")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - 中部：新增表单 / 列表 / 空状态

    @ViewBuilder
    private var content: some View {
        if showAddForm {
            AddTodoView(onDone: {
                withAnimation(.easeInOut(duration: 0.15)) { showAddForm = false }
            })
            .transition(.opacity)
        }
        let items = store.filtered(searchText)
        if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { todo in
                        TodoRowView(todo: todo)
                            .frame(height: rowHeight)
                        Divider()
                            .padding(.leading, 12)
                    }
                }
                .padding(.vertical, 2)
            }
            // 最多可见 5 条，超出后列表内部滚动（自动出现滚动条）
            .frame(height: CGFloat(min(items.count, maxVisibleRows)) * rowHeight, alignment: .top)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "暂无待办，点右上角 + 新增" : "没有匹配「\(searchText)」的事项")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    // MARK: - 底部：数量 + 退出

    private var footer: some View {
        HStack {
            Text("\(store.activeCount) 条待办")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
