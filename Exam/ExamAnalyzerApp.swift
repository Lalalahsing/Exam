import SwiftUI
import SwiftData

@main
struct ExamAnalyzerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Exam.self, QuestionBankItem.self, PracticeSession.self])
    }
}
