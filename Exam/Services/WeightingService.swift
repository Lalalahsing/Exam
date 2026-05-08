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

    /// 以「單元」為粒度抽題：題組視為不可分割的一個單元
    static func selectUnits(
        from pool: [QuestionBankItem],
        count: Int
    ) -> [QuestionUnit] {
        guard !pool.isEmpty else { return [] }

        // 分離題組與獨立題目
        var groupMap: [String: [QuestionBankItem]] = [:]
        var standalones: [QuestionBankItem] = []
        for item in pool {
            if let gid = item.groupId, !gid.isEmpty {
                groupMap[gid, default: []].append(item)
            } else {
                standalones.append(item)
            }
        }

        // 建立 units
        var units: [QuestionUnit] = standalones.map { .single($0) }
        for (gid, qs) in groupMap {
            let sorted = qs.sorted { $0.groupOrder < $1.groupOrder }
            let premise = sorted.first?.groupPremise ?? ""
            units.append(.group(id: gid, premise: premise, questions: sorted))
        }

        let actualCount = min(count, units.count)
        var selected: [QuestionUnit] = []
        var remaining = units

        for _ in 0..<actualCount {
            guard !remaining.isEmpty else { break }
            let weights = remaining.map { $0.weight }
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
                if rand < cumulative { chosenIndex = i; break }
            }
            selected.append(remaining.remove(at: chosenIndex))
        }
        return selected
    }
}
