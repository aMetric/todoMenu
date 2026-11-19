import Carbon.HIToolbox
import AppKit

/// 全局快捷键（默认 Cmd+Shift+T）：任意界面拉起新增待办。
/// 基于 Carbon RegisterEventHotKey，无需辅助功能权限；
/// selftest/截图模式下走 mock，不注册系统热键（CI 无头环境）。
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    /// 系统设置存储 key：面板内开关（默认开启）
    static let enabledKey = "todoMenu.hotKeyEnabled"

    /// selftest 下开关状态的 mock 存储 key（不动真实设置）
    static let mockEnabledKey = "todoMenu.selftest.hotKeyMock"

    static var isEnabled: Bool {
        get {
            if SelfTest.isEnabled || Shot.isActive {
                return UserDefaults.standard.bool(forKey: mockEnabledKey)
            }
            return UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        }
        set {
            if SelfTest.isEnabled || Shot.isActive {
                UserDefaults.standard.set(newValue, forKey: mockEnabledKey)
                return
            }
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }

    /// 是否已向系统注册（真实环境且开关打开）
    private(set) var isRegistered = false
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    /// 热键触发回调（由 AppDelegate 注入，主线程调用）
    var onHotKey: (() -> Void)?

    /// 注册/注销全局热键。返回是否处于注册状态。
    @discardableResult
    func syncRegistration() -> Bool {
        let want = SelfTest.isEnabled || Shot.isActive ? false : Self.isEnabled
        if want == isRegistered { return isRegistered }
        if want {
            installHandlerIfNeeded()
            var hotKeyID = EventHotKeyID(signature: OSType(0x54444B4D) /* TDKM */, id: 1)
            // keyCode 17 = 'T'，cmdKey + shiftKey
            let status = RegisterEventHotKey(
                UInt32(kVK_ANSI_T), UInt32(cmdKey | shiftKey),
                hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
            )
            isRegistered = (status == noErr)
            if status != noErr { hotKeyRef = nil }
        } else {
            if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
            hotKeyRef = nil
            isRegistered = false
        }
        return isRegistered
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(
                event,                 EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            if id.signature == OSType(0x54444B4D), id.id == 1 {
                DispatchQueue.main.async {
                    GlobalHotKey.shared.onHotKey?()
                }
            }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(), callback, 1, &eventType, nil, &eventHandler
        )
    }
}
