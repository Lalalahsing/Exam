import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        MainTabView()
        .task {
            // 舊版 SQLite 資料一次性遷移
            if let dbURL = legacyDatabaseURL() {
                DatabaseMigrator.migrateIfNeeded(context: modelContext, dbURL: dbURL)
            }
        }
    }

    private func legacyDatabaseURL() -> URL? {
        guard let bundleURL = Bundle.main.url(forResource: "exam_data", withExtension: "db") else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("exam_data.db")

        let bundleSize = (try? FileManager.default.attributesOfItem(atPath: bundleURL.path)[.size] as? Int) ?? 0
        let destSize   = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size]   as? Int) ?? -1
        if bundleSize != destSize {
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: bundleURL, to: dest)
        }

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
                ExamFocusView()
            }
            .tabItem { Label("重點", systemImage: "scope") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("設定", systemImage: "gear") }
        }
    }
}
