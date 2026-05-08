import Foundation

/// 練習單元：獨立題目 或 題組（不可拆分）
enum QuestionUnit: Identifiable {
    case single(QuestionBankItem)
    case group(id: String, premise: String, questions: [QuestionBankItem])

    var id: String {
        switch self {
        case .single(let q): return q.id.uuidString
        case .group(let gid, _, _): return gid
        }
    }

    var questions: [QuestionBankItem] {
        switch self {
        case .single(let q): return [q]
        case .group(_, _, let qs): return qs
        }
    }

    /// 加權（題組取平均）
    var weight: Double {
        let ws = questions.map { $0.practiceWeight }
        return ws.isEmpty ? 55.0 : ws.reduce(0, +) / Double(ws.count)
    }

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }
}
