import Foundation
import SwiftData

@Model
final class QuestionBankItem {
    var id: UUID
    var sourceExamId: UUID
    var subject: String
    var volume: String
    var chapterNum: Int
    var chapterName: String
    var topic: String
    var questionNum: Int
    var questionText: String
    var questionType: String
    var optionA: String?
    var optionB: String?
    var optionC: String?
    var optionD: String?
    var correctAnswer: String?
    var difficulty: String
    var firstAttemptCorrect: Bool?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var attempts: [PracticeAttempt]

    init(sourceExamId: UUID, subject: String, volume: String,
         chapterNum: Int, chapterName: String, topic: String,
         questionNum: Int, questionText: String, questionType: String,
         optionA: String? = nil, optionB: String? = nil,
         optionC: String? = nil, optionD: String? = nil,
         correctAnswer: String? = nil, difficulty: String,
         firstAttemptCorrect: Bool? = nil) {
        self.id = UUID()
        self.sourceExamId = sourceExamId
        self.subject = subject
        self.volume = volume
        self.chapterNum = chapterNum
        self.chapterName = chapterName
        self.topic = topic
        self.questionNum = questionNum
        self.questionText = questionText
        self.questionType = questionType
        self.optionA = optionA
        self.optionB = optionB
        self.optionC = optionC
        self.optionD = optionD
        self.correctAnswer = correctAnswer
        self.difficulty = difficulty
        self.firstAttemptCorrect = firstAttemptCorrect
        self.createdAt = Date()
        self.attempts = []
    }

    var attemptCount: Int { attempts.count }

    var errorRate: Double {
        guard !attempts.isEmpty else { return 0 }
        let wrong = attempts.filter { !$0.isCorrect }.count
        return Double(wrong) / Double(attempts.count)
    }

    // 加權演算法：與原 Python 版本一致
    var practiceWeight: Double {
        var weight: Double
        if attempts.isEmpty {
            weight = 55.0   // 未練習過
        } else if errorRate == 0 {
            weight = 10.0   // 全部答對
        } else {
            weight = 20.0 + 80.0 * errorRate  // 有錯誤記錄
        }
        if firstAttemptCorrect == false {
            weight += 15.0  // 原本答錯加權
        }
        return weight
    }

    var difficultyLabel: String {
        switch difficulty {
        case "easy": return "基礎"
        case "medium": return "一般"
        case "hard": return "進階"
        default: return difficulty
        }
    }
}
