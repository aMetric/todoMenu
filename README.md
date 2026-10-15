# TodoMenu

macOS 菜单栏待办应用：常驻菜单栏的 "TODO" 图标，点击弹出极简待办面板。数据只存在本机，无账号、无网络。

A minimal menu bar todo app for macOS. Click the "TODO" icon in the menu bar to open a tiny todo panel. All data is stored locally.

## 特性 Features

- 常驻菜单栏，图标为 "TODO"，点击弹出面板，不占 Dock
- 顶部一行：搜索框（按名称 / 对接人过滤）+ 右侧加号按钮
- 列表最多显示 5 条，超出后列表内部滚动
- 新增待办：名称（必填）、截止时间（可留空）、对接人（选填）；新增时间自动记录
- 鼠标悬停某条时展示完整信息（名称 / 截止时间 / 对接人 / 新增时间）
- 截止时间已过标红、当天标橙；勾选完成后划线置灰
- 数据本地存储：`~/Library/Application Support/TodoMenu/todos.json`

## 系统要求 Requirements

- macOS 14 或更高版本（Apple Silicon / Intel 均可）

## 构建 Build（无需 Xcode）

```bash
# 方式一：一键打包 .app
./scripts/bundle.sh
open build/TodoMenu.app

# 方式二：直接运行（开发调试）
swift run
```

## 安装 Install

把 `build/TodoMenu.app` 拖入 `/Applications` 即可。

> 本项目目前使用 ad-hoc 签名（无需 Apple 开发者账号），仅本机构建运行。
> 若下载他人分发的未公证版本，macOS 可能拦截，右键 → 打开即可，或从源码自行构建。

## 使用 Usage

1. 菜单栏点击 "TODO" 打开面板
2. 点右上角 **+** 新增待办：名称、截止时间、对接人（新增时间自动记录）
3. 点击行首圆圈标记完成；悬停该行出现 🗑 可删除
4. 面板底部可退出应用

## 项目结构 Structure

```text
Package.swift               # SPM 工程定义
Sources/TodoMenu/           # SwiftUI 源码
scripts/bundle.sh           # 一键打包 .app 脚本
PLAN.md                     # 方案与需求文档
```

## Roadmap

- v1.1：编辑待办、开机自启、系统通知提醒、导出
- v1.2：优先级 / 标签、可选的 iCloud 同步

## 开源协议 License

[MIT](./LICENSE)

欢迎提 Issue / PR。Contributions welcome.
