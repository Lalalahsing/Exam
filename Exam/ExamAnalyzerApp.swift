import SwiftUI
import SwiftData

@main
struct ExamAnalyzerApp: App {

    init() {
        // 啟動 iCloud API Key 同步（只需初始化一次）
        _ = AppSettings.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(cloudContainer)
    }

    /// CloudKit 版 ModelContainer，資料自動同步至 iCloud
    private var cloudContainer: ModelContainer {
        let schema = Schema([
            Exam.self,
            ExamQuestion.self,
            QuestionBankItem.self,
            PracticeSession.self,
            PracticeAttempt.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // CloudKit 不可用時（模擬器、無 iCloud 帳號等）退回本地儲存
            print("[App] CloudKit 初始化失敗，改用本地儲存：\(error)")
            let localConfig = ModelConfiguration(schema: schema)
            return try! ModelContainer(for: schema, configurations: localConfig)
        }
    }
}
