# 贡献指南 Contributing

感谢你对 TodoMenu 的关注！欢迎任何形式的贡献：Bug 报告、功能建议、文档改进、代码 PR。

Thanks for your interest in TodoMenu! Bug reports, feature requests, docs and code contributions are all welcome.

## 快速开始 Quick Start

```bash
git clone git@github.com:aMetric/todoMenu.git
cd todoMenu
swift build            # 编译
swift run              # 运行（开发调试）
./scripts/bundle.sh    # 打包 Universal .app

# 冒烟自测（模拟表单开合、增删改，验证无崩溃与弹层尺寸同步）
./build/TodoMenu.app/Contents/MacOS/TodoMenu --selftest
```

环境要求：macOS 14+，Swift 5.9+（仅需 Xcode Command Line Tools）。

## 提交规范 Commit Convention

使用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)：

- `feat:` 新功能
- `fix:` 修复
- `docs:` 文档
- `refactor:` 重构
- `test:` 测试
- `chore:` 构建 / 工具链 / 杂项

示例：`fix: 修复点击添加后应用崩溃的问题`

## 提 Issue

- **Bug**：使用 Bug 报告模板，附上 macOS 版本、芯片架构、复现步骤；崩溃请附 `~/Library/Logs/DiagnosticReports/` 下对应 `.ips` 文件
- **功能建议**：使用功能请求模板，说明使用场景
- 中英文均可

## 提 Pull Request

1. Fork 本仓库并创建分支（如 `feat/edit-todo`）
2. 修改前请确认自测通过：`./build/TodoMenu.app/Contents/MacOS/TodoMenu --selftest`
3. 涉及行为变更时更新 [CHANGELOG.md](CHANGELOG.md) 的 `Unreleased` 部分
4. 保持现有代码风格（中文注释、视图与逻辑分层）
5. 提交 PR，等待 CI 全绿与 review

## 兼容性红线 Compatibility Rules

- 最低支持 macOS 14.0：所有 API 必须面向部署目标 14.0 编译通过（编译器会强制检查）
- 弹层尺寸变化路径（表单开合等）变更后，务必跑一遍 `--selftest` 防回归
- 不要重新引入 `MenuBarExtra(.window)`（见 [PLAN.md](PLAN.md) 实现备注）

## 沟通

优先通过 GitHub Issues 交流；中英文均可。
