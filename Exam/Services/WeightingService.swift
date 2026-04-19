import Foundation
import SwiftData

enum WeightingService {
    /// 加權隨機抽題：與 Python 版邏輯完全一致
    static func selectQuestions(
        from pool: [QuestionBankItem],
        count: Int
    ) -> [QuestionBankItem] {
        guard !pool.isEmpty else { return [] }
        let actualCount = min(count, pool.count)

        var selected: [QuestionBankItem] = []
        var remaining = pool

        for _ in 0..<actualCount {
            guard !remaining.isEmpty else { break }
            let weights = remaining.map { $0.practiceWeight }
            let totalWeight = weights.reduce(0, +)
            guard totalWeight > 0 else {
                selected.append(remaining.removeFirst())
                continue
            }
            let rand = Double.random(in: 0..<totalWeight)
            var cumulative = 0.0
            var chosenIndex = 0
            for (i, w) in weights.enumerated() {
                cumulative += w
                if rand < cumulative {
                    chosenIndex = i
                    break
                }
            }
            selected.append(remaining.remove(at: chosenIndex))
        }
        return selected
    }
}
