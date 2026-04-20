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

        // 4. 最後手段：記憶體模式（不 crash，重開 App 資料清空）
        print("[App] ⚠️ 退回記憶體模式")
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return (try? ModelContainer(for: schema, configurations: cfg))!
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
            let c = try ModelContainer(for: schema)
            print("[App] 本地容器建立成功")
            return c
        } catch {
            print("[App] 本地容器失敗：\(error)")
            return nil
        }
    }

    /// 刪除 Application Support 下所有 SwiftData store 檔案
    private static func deleteAllStoreFiles() {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory,
                                in: .userDomainMask).first else { return }
        let files = (try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []
        for url in files {
            let name = url.lastPathComponent
            if name.hasSuffix(".store") || name.hasSuffix(".store-wal") || name.hasSuffix(".store-shm") {
                try? fm.removeItem(at: url)
                print("[App] 已刪除：\(name)")
            }
        }
    }
}
