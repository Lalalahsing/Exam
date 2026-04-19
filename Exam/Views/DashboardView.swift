import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var allItems: [QuestionBankItem]
    @Query private var sessions: [PracticeSession]
    @State private var selectedSubject: String?

    private var subjects: [String] { Array(Set(allItems.map { $0.subject })).sorted() }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if allItems.isEmpty {
                    ContentUnavailableView(
                        "尚無學習資料",
                        systemImage: "chart.bar",
                        description: Text("上傳考卷後即可查看學習成效")
                    )
                    .padding(.top, 60)
                } else {
                    overallStats
                    subjectSummarySection
                    practiceHistorySection
                    chapterHeatmapSection
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("學習成效")
    }

    // MARK: - Overall Stats

    private var overallStats: some View {
        HStack(spacing: 0) {
            StatCell(value: "\(allItems.count)", label: "題庫總題", color: .blue)
            Divider().frame(height: 50)
            let totalAttempts = allItems.flatMap { $0.attempts }.count
            StatCell(value: "\(totalAttempts)", label: "總練習次", color: .purple)
            Divider().frame(height: 50)
            let correct = allItems.flatMap { $0.attempts }.filter { $0.isCorrect }.count
            let rate = totalAttempts > 0 ? Double(correct) / Double(totalAttempts) : 0
            StatCell(value: String(format: "%.0f%%", rate * 100), label: "整體正確率",
                     color: rate >= 0.8 ? .green : rate >= 0.6 ? .orange : .red)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Subject Summary

    private var subjectSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "各科表現", icon: "books.vertical.fill")

            let subjectData = subjectStats
            Chart(subjectData, id: \.subject) { stat in
                BarMark(
                    x: .value("正確率", stat.rate * 100),
                    y: .value("科目", stat.shortName)
                )
                .foregroundStyle(barColor(rate: stat.rate))
                .annotation(position: .trailing) {
                    Text(String(format: "%.0f%%", stat.rate * 100))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: [0, 60, 80, 100]) {
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .frame(height: CGFloat(subjectData.count) * 40 + 20)
            .padding(.horizontal)

            // 圖例
            HStack(spacing: 16) {
                LegendItem(color: .green, label: "精熟 ≥80%")
                LegendItem(color: .orange, label: "待加強 60-79%")
                LegendItem(color: .red, label: "需複習 <60%")
            }
            .font(.caption)
            .padding(.horizontal)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Practice History

    private var practiceHistorySection: some View {
        let finished = sessions.filter { $0.isFinished }.suffix(10)
        guard !finished.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "近期練習紀錄", icon: "clock.fill")

                Chart(Array(finished.enumerated()), id: \.offset) { i, session in
                    LineMark(
                        x: .value("次", i + 1),
                        y: .value("正確率", session.accuracyRate * 100)
                    )
                    .symbol(Circle())
                    .foregroundStyle(.blue)

                    AreaMark(
                        x: .value("次", i + 1),
                        y: .value("正確率", session.accuracyRate * 100)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 60, 80, 100]) { AxisValueLabel(); AxisGridLine() }
                }
                .frame(height: 160)
                .padding(.horizontal)

                Text("顯示最近 \(finished.count) 次練習的正確率趨勢")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        )
    }

    // MARK: - Chapter Heatmap

    private var chapterHeatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "章節掌握熱圖", icon: "map.fill")

            // 科目選擇
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(subjects, id: \.self) { subject in
                        Button {
                            selectedSubject = selectedSubject == subject ? nil : subject
                        } label: {
                            Text(subject)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedSubject == subject ? Color.blue : Color(.systemFill))
                                .foregroundStyle(selectedSubject == subject ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }

            let displaySubject = selectedSubject ?? subjects.first
            if let subject = displaySubject {
                chapterGrid(subject: subject)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func chapterGrid(subject: String) -> some View {
        let chapters = CurriculumData.allChapters(for: subject)
        let itemsForSubject = allItems.filter { $0.subject == subject }

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
            ForEach(chapters, id: \.chapter.chapterNum) { entry in
                let questions = itemsForSubject.filter {
                    $0.volume == entry.volume && $0.chapterNum == entry.chapter.chapterNum
                }
                let attempts = questions.flatMap { $0.attempts }
                let correct = attempts.filter { $0.isCorrect }.count
                let rate: Double = attempts.isEmpty ? -1 : Double(correct) / Double(attempts.count)

                ChapterCell(
                    volume: entry.volume,
                    chapterNum: entry.chapter.chapterNum,
                    chapterName: entry.chapter.name,
                    questionCount: questions.count,
                    rate: rate
                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var subjectStats: [SubjectStat] {
        subjects.compactMap { subject in
            let items = allItems.filter { $0.subject == subject }
            let attempts = items.flatMap { $0.attempts }
            guard !attempts.isEmpty else { return nil }
            let correct = attempts.filter { $0.isCorrect }.count
            let rate = Double(correct) / Double(attempts.count)
            return SubjectStat(subject: subject, rate: rate)
        }
    }

    private func barColor(rate: Double) -> Color {
        rate >= 0.8 ? .green : rate >= 0.6 ? .orange : .red
    }
}

// MARK: - Sub-types

private struct SubjectStat {
    let subject: String
    let rate: Double
    var shortName: String {
        subject.replacingOccurrences(of: "社會-", with: "").replacingOccurrences(of: "自然-", with: "")
    }
}

private struct ChapterCell: View {
    let volume: String
    let chapterNum: Int
    let chapterName: String
    let questionCount: Int
    let rate: Double  // -1 = no data

    private var bgColor: Color {
        guard rate >= 0 else { return Color(.systemFill) }
        return rate >= 0.8 ? .green.opacity(0.2) : rate >= 0.6 ? .orange.opacity(0.2) : .red.opacity(0.2)
    }
    private var textColor: Color {
        guard rate >= 0 else { return .secondary }
        return rate >= 0.8 ? .green : rate >= 0.6 ? .orange : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(volume).font(.caption2.bold()).foregroundStyle(.secondary)
                Spacer()
                if rate >= 0 {
                    Text(String(format: "%.0f%%", rate * 100))
                        .font(.caption.bold()).foregroundStyle(textColor)
                } else {
                    Text("未測").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Text("第\(chapterNum)章").font(.caption2).foregroundStyle(.secondary)
            Text(chapterName).font(.caption.bold()).lineLimit(2)
            if questionCount > 0 {
                Text("\(questionCount) 題").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}
