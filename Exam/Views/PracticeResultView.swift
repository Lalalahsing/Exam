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
        session.attempts.map { attempt in
            (attempt, allItems.first { $0.id == attempt.questionId })
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 分數卡
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
                .padding(.horizontal)
                .padding(.top)

                // 按題檢視
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

                // 繼續練習按鈕
                Button {
                    dismiss()
                } label: {
                    Label("返回練習設定", systemImage: "arrow.left")
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

    private var rateMessage: String {
        switch rate {
        case 0.9...: return "太棒了！繼續保持！"
        case 0.8..<0.9: return "表現不錯，再加把勁！"
        case 0.6..<0.8: return "有進步空間，多複習錯題"
        default: return "繼續努力，多練習一定會進步！"
        }
    }
}
