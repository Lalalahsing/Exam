import SwiftUI
import SwiftData

@main
struct ExamAnalyzerApp: App {
    private let container: ModelContainer

    init() {
        // iCloud API Key 同步
        _ = AppSettings.shared
        // Container 只建立一次，避免每次 body 重繪重複初始化
        container = Self.buildContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }

    // MARK: - Container 建立

    private static let schema = Schema([
        Exam.self,
        ExamQuestion.self,
        QuestionBankItem.self,
        PracticeSession.self,
        PracticeAttempt.self,
    ])

    private static func buildContainer() -> ModelContainer {
        // 1. 嘗試 CloudKit 版
        do {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("[App] CloudKit 初始化失敗，改用本地儲存：\(error)")
        }

        // 2. 退回本地儲存
        do {
            return try ModelContainer(for: schema)
        } catch {
            // 3. Schema 版本不相容（例如欄位結構變更）→ 清除舊 Store 重建
            print("[App] 本地 Store 載入失敗，清除後重建：\(error)")
            clearLocalStore()
            // 清除後必定可以建立，若仍失敗代表程式碼本身有問題
            return try! ModelContainer(for: schema)
        }
    }

    /// 刪除舊版 SwiftData persistent store（schema 不相容時使用）
    private static func clearLocalStore() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory,
                                       in: .userDomainMask).first else { return }
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            let url = appSupport.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
        }
        print("[App] 已清除舊 SwiftData Store")
    }
}
