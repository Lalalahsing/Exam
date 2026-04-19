import SwiftUI

struct ExamResultView: View {
    let exam: Exam
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 摘要卡片
                summaryCard

                // 分頁
                Picker("檢視", selection: $selectedTab) {
                    Text("題目列表").tag(0)
                    Text("章節分析").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if selectedTab == 0 {
                    questionsSection
                } else {
                    chapterSection
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(exam.subject)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(spacing: 0) {
            StatCell(value: "\(exam.questions.count)", label: "總題數", color: .blue)
            Divider().frame(height: 50)
            StatCell(value: "\(exam.correctCount)", label: "答對", color: .green)
            Divider().frame(height: 50)
            StatCell(value: "\(exam.wrongCount)", label: "答錯", color: .red)
            Divider().frame(height: 50)
            StatCell(
                value: exam.totalAnswered > 0 ? String(format: "%.0f%%", exam.accuracyRate * 100) : "-",
                label: "正確率",
                color: exam.accuracyRate >= 0.8 ? .green : exam.accuracyRate >= 0.6 ? .orange : .red
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Questions

    private var questionsSection: some View {
        LazyVStack(spacing: 10) {
            ForEach(exam.questions.sorted(by: { $0.number < $1.number })) { q in
                QuestionCard(question: q)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Chapter Analysis

    private var chapterSection: some View {
        let grouped = Dictionary(grouping: exam.questions) { "\($0.volume) 第\($0.chapterNum)章 \($0.chapterName)" }
        return LazyVStack(spacing: 10) {
            ForEach(grouped.keys.sorted(), id: \.self) { key in
                let qs = grouped[key]!
                let correct = qs.filter { $0.isCorrect == true }.count
                let total = qs.filter { $0.isCorrect != nil }.count
                ChapterStatRow(title: key, correct: correct, total: total, questionCount: qs.count)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Sub-views

private struct QuestionCard: View {
    let question: ExamQuestion
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                // 答對/錯標記
                if let correct = question.isCorrect {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(correct ? .green : .red)
                        .font(.title3)
                } else {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(.tertiary)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("第 \(question.number) 題 · \(question.questionType)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(question.questionText)
                        .font(.subheadline)
                        .lineLimit(expanded ? nil : 2)
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    // 選項
                    if let a = question.optionA {
                        OptionRow(key: "A", text: a, correctKey: question.correctAnswer, studentKey: question.studentAnswer)
                    }
                    if let b = question.optionB {
                        OptionRow(key: "B", text: b, correctKey: question.correctAnswer, studentKey: question.studentAnswer)
                    }
                    if let c = question.optionC {
                        OptionRow(key: "C", text: c, correctKey: question.correctAnswer, studentKey: question.studentAnswer)
                    }
                    if let d = question.optionD {
                        OptionRow(key: "D", text: d, correctKey: question.correctAnswer, studentKey: question.studentAnswer)
                    }
                    Divider()
                    // 課綱資訊
                    HStack {
                        Label("\(question.volume) 第\(question.chapterNum)章 \(question.chapterName)", systemImage: "book.closed.fill")
                        Spacer()
                        DifficultyBadge(difficulty: question.difficulty)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if !question.topic.isEmpty {
                        Text("知識點：\(question.topic)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

private struct OptionRow: View {
    let key: String
    let text: String
    let correctKey: String?
    let studentKey: String?

    private var isCorrect: Bool { key == correctKey }
    private var isStudent: Bool { key == studentKey }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.caption.bold())
                .frame(width: 20)
                .padding(4)
                .background(isCorrect ? Color.green.opacity(0.2) : (isStudent && !isCorrect ? Color.red.opacity(0.2) : Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(text)
                .font(.caption)
                .foregroundStyle(isCorrect ? .green : (isStudent && !isCorrect ? .red : .primary))
            Spacer()
            if isCorrect { Image(systemName: "checkmark").foregroundStyle(.green).font(.caption2) }
            if isStudent && !isCorrect { Image(systemName: "arrow.left").foregroundStyle(.red).font(.caption2) }
        }
    }
}

private struct ChapterStatRow: View {
    let title: String
    let correct: Int
    let total: Int
    let questionCount: Int

    private var rate: Double { total > 0 ? Double(correct) / Double(total) : 0 }
    private var rateColor: Color { total == 0 ? .gray : rate >= 0.8 ? .green : rate >= 0.6 ? .orange : .red }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.bold())
                Text("\(questionCount) 題").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if total > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", rate * 100))
                        .font(.headline.bold())
                        .foregroundStyle(rateColor)
                    Text("\(correct)/\(total)").font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("無批改").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

struct StatCell: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
