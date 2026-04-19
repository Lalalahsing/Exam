import Foundation
import SwiftData

@Model
final class PracticeSession {
    var id: UUID
    var subject: String
    var volumeFilter: String?
    var questionCount: Int
    var correctCount: Int
    var createdAt: Date
    var finishedAt: Date?
    @Relationship(deleteRule: .cascade) var attempts: [PracticeAttempt]

    init(subject: String, volumeFilter: String? = nil, questionCount: Int) {
        self.id = UUID()
        self.subject = subject
        self.volumeFilter = volumeFilter
        self.questionCount = questionCount
        self.correctCount = 0
        self.createdAt = Date()
        self.attempts = []
    }

    var accuracyRate: Double {
        guard questionCount > 0 else { return 0 }
        return Double(correctCount) / Double(questionCount)
    }

    var isFinished: Bool { finishedAt != nil }
}

@Model
final class PracticeAttempt {
    var id: UUID
    var session: PracticeSession?
    var questionId: UUID
    var isCorrect: Bool
    var attemptedAt: Date

    init(questionId: UUID, isCorrect: Bool) {
        self.id = UUID()
        self.questionId = questionId
        self.isCorrect = isCorrect
        self.attemptedAt = Date()
    }
}
