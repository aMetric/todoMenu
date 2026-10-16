# 变更日志 Changelog

本项目的所有重要变更都会记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Planned

- v1.1：编辑待办、开机自启、系统通知提醒、导出
- v1.2：优先级 / 标签、可选的 iCloud 同步、App 图标

## [0.2.1] - 2026-10-16

### Added

- **DMG 拖拽安装包**：双击打开 → 拖入 Applications 即可使用；Release 同时提供 dmg 与 zip（均为 Universal 二进制，开箱即用，无需编译）
- 开源社区文档套装：CONTRIBUTING / CODE_OF_CONDUCT / SECURITY / Issue 表单 / PR 模板
- README 截图（`--shot` 模式，示例数据生成）

### Fixed

- 修复点击"添加"后应用崩溃：弃用 `MenuBarExtra(.window)`（内容高度变化触发 AppKit 约束异常），改用 `NSStatusItem` + `NSPopover` 经典方案
- 修复 NSPopover 只随内容变大不缩小的问题：新增 `fittingSize` 双向尺寸同步
- 修复发布流程：附件变量展开错误导致 Release 无下载包；标签删除/重建的异步竞态会清掉刚创建的 Release，发布步骤已加"创建后校验 + 重试"

### Changed

- 去掉表单切换动画（规避弹层尺寸变化崩溃）

## [0.2.0] - 2026-10-15

> 未公开发布（被 v0.2.1 取代）。

### Added

- macOS 14（Sonoma）全系兼容：部署目标固定 14.0，所用 API 均受编译器可用性检查约束
- Universal 二进制（Apple Silicon + Intel），`bundle.sh` 自动交叉编译并 `lipo` 合并
- GitHub Actions CI：macOS 14 / 15 环境构建、校验架构与最低系统版本、运行自测、上传产物

## [0.1.0] - 2026-10-15

### Added

- 首个版本：菜单栏 "TODO" 图标 + 弹出面板
- 搜索框（名称 / 对接人）+ 加号按钮
- 列表最多显示 5 条，超出内部滚动
- 新增待办：名称、截止时间、对接人，新增时间自动记录
- 悬停展示完整信息（名称 / 截止时间 / 对接人 / 新增时间）
- 过期标红、当天标橙、完成划线置灰
- 本地 JSON 持久化（带版本号，损坏自动备份重建）
- MIT 协议
