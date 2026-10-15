# 安全策略 Security Policy

## 支持版本 Supported Versions

| 版本 | 支持 |
| --- | --- |
| 0.2.x（最新） | ✅ 安全更新 |
| 0.1.x | ❌ 请升级 |

## 报告漏洞 Reporting a Vulnerability

如发现安全漏洞，请通过 GitHub **Security Advisories** 的"Report a vulnerability"私有通道提交，**请勿公开披露**（不要在公开 Issue 中描述漏洞细节）。维护者将在确认后尽快修复并发布新版本。

请尽量包含：

- 受影响版本
- 复现步骤
- 影响范围评估

## 安全说明

- 本应用**无任何网络功能**：不上传数据、不加载远程内容，数据仅存本机 `~/Library/Application Support/TodoMenu/todos.json`
- 无第三方依赖（零 Swift Package 依赖），依赖面极小
