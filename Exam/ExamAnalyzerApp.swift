import SwiftUI
import SwiftData

@main
struct ExamAnalyzerApp: App {
    private let container: ModelContainer

    init() {
        _ = AppSettings.shared
        container = Self.buildContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }

    // MARK: - Schema

    private static let schema = Schema([
        Exam.self,
        ExamQuestion.self,
        QuestionBankItem.self,
        PracticeSession.self,
        PracticeAttempt.self,
    ])

    // MARK: - Container 建立（絕不 crash）

    private static func buildContainer() -> ModelContainer {
        // 1. 嘗試 CloudKit 版
        if let c = makeCloudKitContainer() { return c }

        // 2. 嘗試本地版
        if let c = makeLocalContainer() { return c }

        // 3. 清除舊 Store 後重試本地版
        print("[App] 清除舊 Store 並重建…")
        deleteAllStoreFiles()
        if let c = makeLocalContainer() { return c }

        // 4. 最後手段：記憶體模式（重開 App 資料清空）
        // isStoredInMemoryOnly + cloudKitDatabase: .none 雙重保險，
        // 防止 .automatic 預設值在有 CloudKit entitlement 時觸發 loadIssueModelContainer
        print("[App] ⚠️ 退回記憶體模式")
        do {
            let cfg = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: cfg)
        } catch {
            fatalError("[App] 記憶體容器建立失敗，無法繼續：\(error)")
        }
    }

    private static func makeCloudKitContainer() -> ModelContainer? {
        do {
            let cfg = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            let c = try ModelContainer(for: schema, configurations: cfg)
            print("[App] CloudKit 容器建立成功")
            return c
        } catch {
            print("[App] CloudKit 不可用：\(error)")
            return nil
        }
    }

    private static func makeLocalContainer() -> ModelContainer? {
        do {
            // cloudKitDatabase: .none 明確停用 CloudKit，避免觸發 loadIssueModelContainer
            let cfg = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            let c = try ModelContainer(for: schema, configurations: cfg)
            print("[App] 本地容器建立成功")
            return c
        } catch {
            print("[App] 本地容器失敗：\(error)")
            return nil
        }
    }

    /// 遞迴刪除 Application Support 下所有 SwiftData store 檔案
    private static func deleteAllStoreFiles() {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory,
                                in: .userDomainMask).first else { return }
        guard let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if name.hasSuffix(".store") || name.hasSuffix(".store-wal") || name.hasSuffix(".store-shm") {
                try? fm.removeItem(at: url)
                print("[App] 已刪除：\(name)")
            }
        }
    }
}
