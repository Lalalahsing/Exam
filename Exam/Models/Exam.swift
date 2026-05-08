import Foundation
import SwiftData

@Model
final class Exam {
    var id: UUID
    var subject: String
    var imageName: String
    var createdAt: Date
    var rawJson: String
    var notes: String
    var pageImageNames: [String]   // 所有頁面圖片檔名（第0頁即 imageName）
    @Relationship(deleteRule: .cascade) var questions: [ExamQuestion]?

    init(subject: String, imageName: String, rawJson: String, notes: String = "",
         pageImageNames: [String] = []) {
        self.id = UUID()
        self.subject = subject
        self.imageName = imageName
        self.createdAt = Date()
        self.rawJson = rawJson
        self.notes = notes
        self.pageImageNames = pageImageNames
        self.questions = []
    }

    private var questionList: [ExamQuestion] { questions ?? [] }
    var correctCount: Int { questionList.filter { $0.isCorrect == true }.count }
    var wrongCount: Int { questionList.filter { $0.isCorrect == false }.count }
    var totalAnswered: Int { questionList.filter { $0.isCorrect != nil }.count }
    var accuracyRate: Double {
        guard totalAnswered > 0 else { return 0 }
        return Double(correctCount) / Double(totalAnswered)
    }
}

@Model
final class ExamQuestion {
    var id: UUID
    var exam: Exam?
    var number: Int
    var questionText: String
    var questionType: String
    var optionA: String?
    var optionB: String?
    var optionC: String?
    var optionD: String?
    var correctAnswer: String?
    var studentAnswer: String?
    var isCorrect: Bool?
    var volume: String
    var chapterNum: Int
    var chapterName: String
    var topic: String
    var difficulty: String
    var confidence: String
    var groupId: String?
    var groupPremise: String?
    var groupOrder: Int
    var figureImageName: String?

    init(number: Int, questionText: String, questionType: String,
         optionA: String? = nil, optionB: String? = nil,
         optionC: String? = nil, optionD: String? = nil,
         correctAnswer: String? = nil, studentAnswer: String? = nil,
         isCorrect: Bool? = nil, volume: String, chapterNum: Int,
         chapterName: String, topic: String, difficulty: String, confidence: String,
         groupId: String? = nil, groupPremise: String? = nil, groupOrder: Int = 0,
         figureImageName: String? = nil) {
        self.id = UUID()
        self.number = number
        self.questionText = questionText
        self.questionType = questionType
        self.optionA = optionA
        self.optionB = optionB
        self.optionC = optionC
        self.optionD = optionD
        self.correctAnswer = correctAnswer
        self.studentAnswer = studentAnswer
        self.isCorrect = isCorrect
        self.volume = volume
        self.chapterNum = chapterNum
        self.chapterName = chapterName
        self.topic = topic
        self.difficulty = difficulty
        self.confidence = confidence
        self.groupId = groupId
        self.groupPremise = groupPremise
        self.groupOrder = groupOrder
        self.figureImageName = figureImageName
    }
}
