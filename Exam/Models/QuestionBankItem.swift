import Foundation
import SwiftData

@Model
final class QuestionBankItem {
    var id: UUID
    var sourceExamId: UUID
    var year: Int               // 0 = 未知；103–113 = 會考年份
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
    var passRate: Double        // -1 = 未知；0.0–1.0 = 全國通過率
    var difficulty: String
    var explanation: String     // AI 解析
    var firstAttemptCorrect: Bool?
    var createdAt: Date
    /// 練習累計次數（直接存儲，不使用 relationship 以避免 SwiftData 雙重 owner 問題）
    var attemptCount: Int = 0
    /// 練習累計答對次數
    var correctAttemptCount: Int = 0
    var figureImageName: String?
    var tableJson: String?          // 編碼為 JSON 字串的 TableData
    // 題組欄位（nil 表示獨立題目）
    var groupId: String?
    var groupPremise: String?
    var groupOrder: Int

    init(sourceExamId: UUID, year: Int = 0, subject: String, volume: String,
         chapterNum: Int, chapterName: String, topic: String,
         questionNum: Int, questionText: String, questionType: String,
         optionA: String? = nil, optionB: String? = nil,
         optionC: String? = nil, optionD: String? = nil,
         correctAnswer: String? = nil,
         passRate: Double = -1,
         difficulty: String,
         explanation: String = "",
         firstAttemptCorrect: Bool? = nil,
         groupId: String? = nil, groupPremise: String? = nil, groupOrder: Int = 0,
         figureImageName: String? = nil,
         tableJson: String? = nil) {
        self.id = UUID()
        self.sourceExamId = sourceExamId
        self.year = year
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
        self.passRate = passRate
        self.difficulty = difficulty
        self.explanation = explanation
        self.firstAttemptCorrect = firstAttemptCorrect
        self.createdAt = Date()
        self.attemptCount = 0
        self.correctAttemptCount = 0
        self.groupId = groupId
        self.groupPremise = groupPremise
        self.groupOrder = groupOrder
        self.figureImageName = figureImageName
        self.tableJson = tableJson
    }

    var errorRate: Double {
        guard attemptCount > 0 else { return 0 }
        return Double(attemptCount - correctAttemptCount) / Double(attemptCount)
    }

    var practiceWeight: Double {
        var weight: Double
        if attemptCount == 0 {
            weight = 55.0
        } else if errorRate == 0 {
            weight = 10.0
        } else {
            weight = 20.0 + 80.0 * errorRate
        }
        if firstAttemptCorrect == false {
            weight += 15.0
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

    /// 通過率轉難度描述（補充 difficulty 欄位）
    var passRateLabel: String? {
        guard passRate >= 0 else { return nil }
        switch passRate {
        case 0.8...: return "偏易"
        case 0.5..<0.8: return "中等"
        default: return "偏難"
        }
    }

    /// 民國年顯示，e.g. "113年會考"
    var yearLabel: String? {
        guard year > 0 else { return nil }
        return "\(year)年會考"
    }
}
