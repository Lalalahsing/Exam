import Foundation

/// 負責將 API Key 雙向同步到 iCloud Key-Value Store。
/// 不需要修改任何 View：@AppStorage("anthropicAPIKey") 寫入 UserDefaults 時，
/// 此類別自動把最新值推送到 iCloud；另一台裝置上的 iCloud 變動也會回寫 UserDefaults，
/// 讓 @AppStorage 自動感知更新。
final class AppSettings {
    static let shared = AppSettings()
    private let kvStore = NSUbiquitousKeyValueStore.default
    private static let key = "anthropicAPIKey"
    private var isSyncing = false   // 防止循環觸發

    private init() {
        // 啟動時：優先用 iCloud 值覆蓋本地（若 iCloud 有值）
        syncCloudToLocal()
        kvStore.synchronize()

        // 監聽：iCloud 有外部裝置更新 → 寫回 UserDefaults
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChangeExternally(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )

        // 監聽：本地 UserDefaults 被寫入（包含 @AppStorage）→ 推送到 iCloud
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    // MARK: - Private

    private func syncCloudToLocal() {
        let cloudValue = kvStore.string(forKey: Self.key) ?? ""
        guard !cloudValue.isEmpty else { return }
        let localValue = UserDefaults.standard.string(forKey: Self.key) ?? ""
        if cloudValue != localValue {
            isSyncing = true
            UserDefaults.standard.set(cloudValue, forKey: Self.key)
            isSyncing = false
            print("[AppSettings] 從 iCloud 同步 API Key")
        }
    }

    @objc private func kvStoreDidChangeExternally(_ notification: Notification) {
        guard
            let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
            keys.contains(Self.key)
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.syncCloudToLocal()
        }
    }

    @objc private func userDefaultsDidChange(_ notification: Notification) {
        guard !isSyncing else { return }
        let localValue  = UserDefaults.standard.string(forKey: Self.key) ?? ""
        let cloudValue  = kvStore.string(forKey: Self.key) ?? ""
        guard localValue != cloudValue else { return }
        kvStore.set(localValue, forKey: Self.key)
        kvStore.synchronize()
        print("[AppSettings] 推送 API Key 至 iCloud")
    }
}
