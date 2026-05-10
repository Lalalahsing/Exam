import SwiftUI
import SwiftData

/// 會考重點分析：按科目 → 冊次（七上→九下）→ 章節順序，
/// 統計歷屆出題次數、出現年份、平均通過率、常考主題與個人練習表現。
struct ExamFocusView: View {
    @Query(filter: #Predicate<QuestionBankItem> { $0.year > 0 })
    private var pastItems: [QuestionBankItem]

    @State private var selectedSubject: String = CurriculumData.subjects.first ?? "數學"

    private var availableSubjects: [String] {
        // 只顯示題庫實際有出題的科目，按 CurriculumData 順序
        let exists = Set(pastItems.map(\.subject))
        return CurriculumData.subjects.filter { exists.contains($0) }
    }

    var body: some View {
        Group {
            if pastItems.isEmpty {
                ContentUnavailableView(
                    "尚無題庫資料",
                    systemImage: "scope",
                    description: Text("題庫匯入後可分析會考重點章節")
                )
            } else {
                contentList
            }
        }
        .navigationTitle("會考重點分析")
        .onAppear {
            if !availableSubjects.contains(selectedSubject),
               let first = availableSubjects.first {
                selectedSubject = first
            }
        }
    }

    private var contentList: some View {
        List {
            Section {
                subjectPicker
            }

            Section {
                summaryCard(for: selectedSubject)
            }

            ForEach(CurriculumData.volumes, id: \.self) { volume in
                let entries = chaptersWithStats(subject: selectedSubject, volume: volume)
                if !entries.isEmpty {
                    Section(volume) {
                        ForEach(entries, id: \.chapterNum) { entry in
                            ChapterFocusRow(stat: entry)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subject Picker

    private var subjectPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableSubjects, id: \.self) { subject in
                    Button { selectedSubject = subject } label: {
                        Text(subject)
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedSubject == subject ? Color.blue : Color(.systemFill))
                            .foregroundStyle(selectedSubject == subject ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
    }

    // MARK: - Summary

    private func summaryCard(for subject: String) -> some View {
        let items = pastItems.filter { $0.subject == subject }
        let years = Set(items.map(\.year)).sorted()
        let withPass = items.filter { $0.passRate >= 0 }
        let avgPass = withPass.isEmpty ? 0 : withPass.map(\.passRate).reduce(0, +) / Double(withPass.count)
        let coveredChapters = Set(items.map { "\($0.volume)-\($0.chapterNum)" }).count
        let totalChapters = CurriculumData.allChapters(for: subject).count

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                FocusStatCell(value: "\(items.count)", label: "歷屆題數", color: .blue)
                Divider().frame(height: 36)
                FocusStatCell(value: "\(years.count)", label: "涵蓋年份", color: .purple)
                Divider().frame(height: 36)
                FocusStatCell(value: "\(coveredChapters)/\(totalChapters)",
                              label: "涉及章節", color: .teal)
                if avgPass > 0 {
                    Divider().frame(height: 36)
                    FocusStatCell(value: String(format: "%.0f%%", avgPass * 100),
                                  label: "平均通過率",
                                  color: avgPass >= 0.7 ? .green : avgPass >= 0.5 ? .orange : .red)
                }
            }
            if !years.isEmpty {
                Text("涵蓋年份：\(years.map { "\($0)" }.joined(separator: "、"))年")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Stats

    private func chaptersWithStats(subject: String, volume: String) -> [ChapterFocusStat] {
        let chapters = CurriculumData.chapters(for: subject, volume: volume)
        let subjectItems = pastItems.filter { $0.subject == subject && $0.volume == volume }

        return chapters.map { ch in
            let items = subjectItems.filter { $0.chapterNum == ch.chapterNum }
            let years = Set(items.map(\.year)).sorted()
            let withPass = items.filter { $0.passRate >= 0 }
            let avgPass = withPass.isEmpty ? -1 : withPass.map(\.passRate).reduce(0, +) / Double(withPass.count)
            let topTopics = topicCounts(items: items)
            let userAttempts = items.reduce(0) { $0 + $1.attemptCount }
            let userCorrect  = items.reduce(0) { $0 + $1.correctAttemptCount }
            let userRate: Double = userAttempts == 0 ? -1 : Double(userCorrect) / Double(userAttempts)

            return ChapterFocusStat(
                volume: volume,
                chapterNum: ch.chapterNum,
                chapterName: ch.name,
                count: items.count,
                years: years,
                avgPassRate: avgPass,
                topTopics: topTopics,
                userPracticeRate: userRate,
                userAttempts: userAttempts
            )
        }
    }

    private func topicCounts(items: [QuestionBankItem]) -> [(String, Int)] {
        let counts = Dictionary(grouping: items, by: \.topic)
            .mapValues(\.count)
            .filter { !$0.key.isEmpty }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }
}

// MARK: - Sub-types

private struct ChapterFocusStat {
    let volume: String
    let chapterNum: Int
    let chapterName: String
    let count: Int
    let years: [Int]
    let avgPassRate: Double      // -1 表示無資料
    let topTopics: [(String, Int)]
    let userPracticeRate: Double // -1 表示尚未練習
    let userAttempts: Int
}

private struct ChapterFocusRow: View {
    let stat: ChapterFocusStat

    private var heatColor: Color {
        switch stat.count {
        case 0:     return .secondary
        case 1...2: return .green
        case 3...5: return .orange
        default:    return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 標頭：章節名 + 出題次數
            HStack(alignment: .firstTextBaseline) {
                Text("第\(stat.chapterNum)章 \(stat.chapterName)")
                    .font(.subheadline.bold())
                Spacer()
                if stat.count == 0 {
                    Text("未出題")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.caption2)
                        Text("\(stat.count) 題")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(heatColor)
                }
            }

            if stat.count > 0 {
                // 出現年份
                if !stat.years.isEmpty {
                    Text("年份：\(stat.years.map { "\($0)" }.joined(separator: "、"))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // 通過率 / 個人正確率
                HStack(spacing: 14) {
                    if stat.avgPassRate >= 0 {
                        Label(String(format: "全國 %.0f%%", stat.avgPassRate * 100),
                              systemImage: "person.3.fill")
                            .foregroundStyle(passRateColor(stat.avgPassRate))
                    }
                    if stat.userPracticeRate >= 0 {
                        Label(String(format: "我 %.0f%% (%d次)",
                                     stat.userPracticeRate * 100, stat.userAttempts),
                              systemImage: "person.fill")
                            .foregroundStyle(passRateColor(stat.userPracticeRate))
                    }
                }
                .font(.caption)

                // 常考主題
                if !stat.topTopics.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(stat.topTopics, id: \.0) { topic, n in
                            Text("\(topic)\(n > 1 ? " ×\(n)" : "")")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func passRateColor(_ rate: Double) -> Color {
        rate >= 0.7 ? .green : rate >= 0.5 ? .orange : .red
    }
}

private struct FocusStatCell: View {
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
