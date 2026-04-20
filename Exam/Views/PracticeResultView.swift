import SwiftUI
import SwiftData

struct PracticeResultView: View {
    let session: PracticeSession
    @Environment(\.dismiss) private var dismiss
    @Query private var allItems: [QuestionBankItem]

    private var correctCount: Int { session.correctCount }
    private var total: Int { session.questionCount }
    private var rate: Double { total > 0 ? Double(correctCount) / Double(total) : 0 }

    private var rateColor: Color {
        rate >= 0.8 ? .green : rate >= 0.6 ? .orange : .red
    }

    private var attemptedQuestions: [(attempt: PracticeAttempt, question: QuestionBankItem?)] {
        (session.attempts ?? []).map { attempt in
            (attempt, allItems.first { $0.id == attempt.questionId })
        }
    }

    // 答錯題目按章節分組，依錯誤數量排序
    private var wrongChapterGroups: [(key: String, questions: [QuestionBankItem])] {
        let wrongPairs = attemptedQuestions.filter { !$0.attempt.isCorrect }
        var grouped: [String: [QuestionBankItem]] = [:]
        for pair in wrongPairs {
            guard let q = pair.question else { continue }
            let key = "\(q.volume) · \(q.chapterName)"
            grouped[key, default: []].append(q)
        }
        return grouped.sorted { $0.value.count > $1.value.count }.map { (key: $0.key, questions: $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 分數卡
                scoreCard
                    .padding(.horizontal)
                    .padding(.top)

                // 錯誤章節分析
                if !wrongChapterGroups.isEmpty {
                    wrongChapterSection
                }

                // 按題檢視
                questionDetailSection

                // 操作按鈕
                Button {
                    dismiss()
                } label: {
                    Label("再練一輪", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("練習結果")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 12)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(rateColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: rate)
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", rate * 100))
                        .font(.title.bold())
                        .foregroundStyle(rateColor)
                    Text("正確率")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 32) {
                VStack {
                    Text("\(correctCount)").font(.title2.bold()).foregroundStyle(.green)
                    Text("答對").font(.caption).foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(total - correctCount)").font(.title2.bold()).foregroundStyle(.red)
                    Text("答錯").font(.caption).foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(total)").font(.title2.bold())
                    Text("總題數").font(.caption).foregroundStyle(.secondary)
                }
            }

            Text(rateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Wrong Chapter Analysis

    private var wrongChapterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("錯誤章節分析")
                .font(.headline)
                .padding(.horizontal)

            ForEach(wrongChapterGroups, id: \.key) { item in
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.key)
                            .font(.subheadline)
                    }
                    Spacer()
                    Text("答錯 \(item.questions.count) 題")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    // 進度條視覺化（每題 15px，上限 60px）
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemFill))
                            .frame(width: 60, height: 6)
                        Capsule()
                            .fill(Color.red)
                            .frame(width: min(CGFloat(item.questions.count) * 15, 60), height: 6)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Question Detail

    private var questionDetailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本次作答明細")
                .font(.headline)
                .padding(.horizontal)

            ForEach(Array(attemptedQuestions.enumerated()), id: \.offset) { i, pair in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: pair.attempt.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(pair.attempt.isCorrect ? .green : .red)
                        .font(.title3)

                    if let q = pair.question {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(q.questionText)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text("\(q.volume) · \(q.chapterName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // 答錯時顯示正確答案
                            if !pair.attempt.isCorrect, let answer = q.correctAnswer, !answer.isEmpty {
                                Text("正確答案：\(answer)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                    } else {
                        Text("題目 #\(i + 1)").font(.subheadline)
                    }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    private var rateMessage: String {
        switch rate {
        case 0.9...: return "太棒了！繼續保持！"
        case 0.8..<0.9: return "表現不錯，再加把勁！"
        case 0.6..<0.8: return "有進步空間，多複習錯題"
        default: return "繼續努力，多練習一定會進步！"
        }
    }
}
