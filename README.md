<div align="center">

# TodoMenu

**极简的 macOS 菜单栏待办清单** · A minimal menu bar todo list for macOS

[![CI](https://github.com/aMetric/todoMenu/actions/workflows/ci.yml/badge.svg)](https://github.com/aMetric/todoMenu/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue.svg?logo=apple)](https://github.com/aMetric/todoMenu)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138.svg?logo=swift)](https://www.swift.org)
[![Apple Silicon & Intel](https://img.shields.io/badge/Universal%20Binary-black.svg?logo=apple)](https://github.com/aMetric/todoMenu)
[![Stars](https://img.shields.io/github/stars/aMetric/todoMenu?style=social)](https://github.com/aMetric/todoMenu)

</div>

常驻菜单栏的 **"TODO"** 图标，点击弹出极简待办面板。**数据只存在本机，无账号、无网络。** 原生 SwiftUI 实现，包体约 400KB。

A **"TODO"** icon lives in your menu bar; click it to open a tiny todo panel. **Local-only. No account. No network.** Native SwiftUI, ~400KB.

## 预览 Preview

![TodoMenu 面板](docs/screenshot.png)

## ✨ 特性 Features

- 🖥 常驻菜单栏，图标为 "TODO"，不占 Dock，点击面板外自动收起
- 🔍 顶部搜索框（按名称 / 明细 / 对接人实时过滤）+ 右侧 ➕ 按钮
- 📋 列表最多显示 5 条，超出后列表内部滚动
- ➕ 新增待办：名称（必填）、明细（选填，多行：会议要点 / 领导原话）、截止时间（可留空）、对接人（选填）；**新增时间自动记录**
- 👆 鼠标悬停某条时展示完整信息（名称 / 明细 / 截止时间 / 对接人 / 新增时间）
- ⏰ 截止时间已过标红、当天标橙；勾选完成后划线置灰
- 🔥 列表按紧急度排序：逾期 > 今天到期 > 未来有截止时间 > 无截止时间 > 已完成
- 💾 数据本地存储：`~/Library/Application Support/TodoMenu/todos.json`（带版本号，损坏自动备份重建）

## 安装 Installation

### 下载安装包（推荐，无需编译）

前往 [Releases](../../releases) 下载最新版：

- **`.dmg`**（推荐）：双击打开，把 TodoMenu 拖入 Applications 即可
- `.zip`：解压后把 TodoMenu.app 拖入 `/Applications`

两者都是开箱即用的 Universal 二进制（Apple Silicon + Intel），macOS 14+。

> 当前版本使用 ad-hoc 签名（无需 Apple 开发者账号）。首次打开若被拦截，**右键 → 打开**即可。

### 从源码构建

```bash
git clone git@github.com:aMetric/todoMenu.git
cd todoMenu
./scripts/bundle.sh          # 产出 Universal .app（arm64 + x86_64）
open build/TodoMenu.app
```

### Homebrew

`brew install --cask todo-menu` 计划在首个正式 Release 后提交至 homebrew-cask。欢迎通过 [Issue](../../issues) 催更或共建。

## 使用 Usage

1. 菜单栏点击 **TODO** 打开面板
2. 点右上角 **+** 新增待办：名称（必填）、明细（选填，可多行）、截止时间（可留空）、对接人（选填）
3. 点击行首圆圈标记完成；悬停该行出现 ✏️ 可编辑、🗑 可删除
4. **Cmd+N** 快速新增（表单自动聚焦名称，Enter 保存，Esc 收起）
5. 删除 / 完成后 4 秒内可点底部 **撤销**（或 **Cmd+Z**）恢复
6. 面板右下角 **退出** 可退出应用

## 数据与隐私 Data & Privacy

- 全部数据保存在本机单文件 `~/Library/Application Support/TodoMenu/todos.json`（JSON，UTF-8，带版本号）
- 无任何网络请求、无埋点、无第三方 SDK
- 删除应用时同步删除该目录即可彻底清除数据

## 兼容性 Compatibility

| 环境 | 状态 |
| --- | --- |
| macOS 15 (Sequoia) | ✅ CI 持续验证 |
| **macOS 14 (Sonoma)** | ✅ **最低支持版本**，CI 持续验证 |
| macOS 13 及更早 | ❌ 不支持 |
| Apple Silicon (M1+) | ✅ Universal 二进制 |
| Intel | ✅ Universal 二进制 |

部署目标固定为 macOS 14.0，所有 API 均受编译器可用性检查约束，保证不依赖更高版本系统能力。

## 开发 Development

环境要求：macOS 14+，Swift 5.9+（仅需 Xcode Command Line Tools，无需完整 Xcode）。

```bash
swift run                    # 直接运行（开发调试，本机架构）
./scripts/bundle.sh          # 打包 Universal .app

# 自动化冒烟测试：模拟表单开合、增删改操作，验证无崩溃且弹层尺寸同步
./build/TodoMenu.app/Contents/MacOS/TodoMenu --selftest

# 生成 README 截图（使用示例数据，不读取真实数据）
./build/TodoMenu.app/Contents/MacOS/TodoMenu --shot docs/screenshot.png
```

架构说明见 [PLAN.md](PLAN.md)（方案、数据模型、兼容性策略、实现备注）。

## 项目结构 Structure

```text
Package.swift                 # SPM 工程定义（macOS 14+，零依赖）
Sources/TodoMenu/             # SwiftUI 源码（AppKit 外壳 + SwiftUI 视图）
scripts/bundle.sh             # 一键打包 Universal .app
.github/workflows/ci.yml      # CI：macOS 14/15 构建 + 自测 + 产物
docs/                         # 截图等资源
PLAN.md                       # 方案与需求文档
CHANGELOG.md                  # 变更日志
```

## Roadmap

- v1.1：编辑待办、开机自启、系统通知提醒、导出
- v1.2：优先级 / 标签、可选的 iCloud 同步、App 图标与 DMG

欢迎在 [Issues](../../issues) 提需求投票。

## 贡献 Contributing

欢迎任何形式的贡献：Bug 报告、功能建议、文档、代码。请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

- 行为准则：[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- 安全漏洞报告：[SECURITY.md](SECURITY.md)
- 变更日志：[CHANGELOG.md](CHANGELOG.md)

## 开源协议 License

[MIT](LICENSE) © 2025 TodoMenu contributors
