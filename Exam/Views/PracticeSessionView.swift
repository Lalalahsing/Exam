import SwiftUI
import SwiftData

struct PracticeSessionView: View {
    let config: PracticeSessionConfig
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allItems: [QuestionBankItem]

    @State private var session: PracticeSession?
    @State private var questions: [QuestionBankItem] = []
    @State private var currentIndex = 0
    @State private var showAnswer = false
    @State private var isFinished = false
    @State private var showExitAlert = false

    private var current: QuestionBankItem? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var body: some View {
        Group {
            if isFinished, let session {
                PracticeResultView(session: session)
            } else if let question = current {
                practiceCard(question: question)
            } else {
                ProgressView("準備題目中…")
            }
        }
        .navigationTitle("練習中")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("結束") { showExitAlert = true }
            }
            ToolbarItem(placement: .principal) {
                if !questions.isEmpty {
                    Text("\(currentIndex + 1) / \(questions.count)")
                        .font(.subheadline.bold())
                }
            }
        }
        .alert("結束練習？", isPresented: $showExitAlert) {
            Button("結束", role: .destructive) { dismiss() }
            Button("繼續", role: .cancel) {}
        }
        .task { setupSession() }
    }

    // MARK: - Practice Card

    @ViewBuilder
    private func practiceCard(question: QuestionBankItem) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // 進度條
                ProgressView(value: Double(currentIndex), total: Double(questions.count))
                    .padding(.horizontal)

                // 題目資訊
                HStack {
                    SubjectBadge(subject: question.subject, style: .full)
                    Text("\(question.volume) 第\(question.chapterNum)章")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DifficultyBadge(difficulty: question.difficulty)
                }
                .padding(.horizontal)

                // 題目卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("第 \(question.questionNum) 題")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(question.questionText)
                        .font(.body)

                    if let a = question.optionA {
                        Divider()
                        ForEach([("A", a), ("B", question.optionB ?? ""), ("C", question.optionC ?? ""), ("D", question.optionD ?? "")].filter { !$0.1.isEmpty }, id: \.0) { key, text in
                            HStack(alignment: .top, spacing: 10) {
                                Text(key)
                                    .font(.caption.bold())
                                    .frame(width: 22)
                                    .padding(4)
                                    .background(showAnswer && key == question.correctAnswer
                                                ? Color.green.opacity(0.2) : Color(.systemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                Text(text)
                                    .font(.subheadline)
                                    .foregroundStyle(showAnswer && key == question.correctAnswer ? .green : .primary)
                            }
                        }
                    }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                .padding(.horizontal)

                // 答案區
                if showAnswer {
                    VStack(spacing: 8) {
                        if let ans = question.correctAnswer {
                            HStack {
                                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                                Text("正確答案：\(ans)")
                                    .font(.headline.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                        Text(question.topic)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // 自評按鈕
                    HStack(spacing: 16) {
                        Button {
                            recordAnswer(isCorrect: false)
                        } label: {
                            Label("答錯", systemImage: "xmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        Button {
                            recordAnswer(isCorrect: true)
                        } label: {
                            Label("答對", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.12))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal)
                    .font(.headline)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showAnswer = true }
                    } label: {
                        Label("查看答案", systemImage: "eye.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Logic

    private func setupSession() {
        let pool = allItems.filter { item in
            let matchSub = config.subject == "全部" || item.subject == config.subject
            let matchVol = config.volume == nil || item.volume == config.volume
            return matchSub && matchVol
        }
        questions = WeightingService.selectQuestions(from: pool, count: config.count)
        let s = PracticeSession(
            subject: config.subject,
            volumeFilter: config.volume,
            questionCount: questions.count
        )
        modelContext.insert(s)
        session = s
    }

    private func recordAnswer(isCorrect: Bool) {
        guard let question = current, let session else { return }
        let attempt = PracticeAttempt(questionId: question.id, isCorrect: isCorrect)
        attempt.session = session
        session.attempts.append(attempt)
        question.attempts.append(attempt)
        modelContext.insert(attempt)
        if isCorrect { session.correctCount += 1 }

        withAnimation {
            showAnswer = false
            currentIndex += 1
            if currentIndex >= questions.count {
                session.finishedAt = Date()
                try? modelContext.save()
                isFinished = true
            }
        }
    }
}
