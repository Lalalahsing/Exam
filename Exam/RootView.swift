import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if apiKey.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .task {
            // 舊版 SQLite 資料一次性遷移
            if let dbURL = legacyDatabaseURL() {
                DatabaseMigrator.migrateIfNeeded(context: modelContext, dbURL: dbURL)
            }
        }
    }

    private func legacyDatabaseURL() -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("exam_data.db")
        if FileManager.default.fileExists(atPath: dest.path) { return dest }
        guard let bundleURL = Bundle.main.url(forResource: "exam_data", withExtension: "db") else { return nil }
        try? FileManager.default.copyItem(at: bundleURL, to: dest)
        return FileManager.default.fileExists(atPath: dest.path) ? dest : nil
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("首頁", systemImage: "house.fill") }

            NavigationStack {
                QuestionBankView()
            }
            .tabItem { Label("題庫", systemImage: "books.vertical.fill") }

            NavigationStack {
                PracticeSetupView()
            }
            .tabItem { Label("練習", systemImage: "pencil.and.list.clipboard") }

            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("成效", systemImage: "chart.bar.fill") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("設定", systemImage: "gear") }
        }
    }
}
