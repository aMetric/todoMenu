import Foundation
import ServiceManagement

/// 开机自启：SMAppService.mainApp（macOS 13+ 系统原生登录项，无需 Apple Events 权限）。
/// 注意：登录项按 app bundle 路径注册，应用移动位置（如换目录安装）后需重新开启。
enum LaunchAtLogin {
    /// 是否运行在真正的 .app bundle 内（swift run 调试时不是，SMAppService 无效）
    private static var isBundled: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }

    /// 真实注册状态（SMAppService；未打包时恒为 false，避免误注册）
    static var realIsEnabled: Bool {
        guard isBundled else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// UI 呈现的状态：selftest 模式走 UserDefaults mock（CI 无头环境不污染真实登录项）
    static var isEnabled: Bool {
        if SelfTest.isEnabled {
            return UserDefaults.standard.bool(forKey: SelfTest.mockAutoLaunchKey)
        }
        return realIsEnabled
    }

    /// 切换注册状态，返回切换后的状态
    @discardableResult
    static func toggle() -> Bool {
        // selftest：mock 翻转，验证 UI 接线与状态同步
        if SelfTest.isEnabled {
            let next = !isEnabled
            UserDefaults.standard.set(next, forKey: SelfTest.mockAutoLaunchKey)
            return next
        }
        guard isBundled else {
            print("AUTOLAUNCH: 仅安装在 .app bundle 内才支持开机自启")
            return false
        }
        do {
            if realIsEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("AUTOLAUNCH: \(realIsEnabled ? "unregister" : "register") 失败：\(error.localizedDescription)")
        }
        return realIsEnabled
    }
}
