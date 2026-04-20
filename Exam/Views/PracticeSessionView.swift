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
    @State private var selectedAnswer: String? = nil
    @State private var eliminatedOptions: Set<String> = []
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
        let isMultipleChoice = question.optionA != nil
        let options = [("A", question.optionA), ("B", question.optionB),
                       ("C", question.optionC), ("D", question.optionD)]
            .compactMap { key, val -> (String, String)? in
                guard let v = val, !v.isEmpty else { return nil }
                return (key, v)
            }

        ScrollView {
            VStack(spacing: 20) {
                ProgressView(value: Double(currentIndex), total: Double(questions.count))
                    .padding(.horizontal)

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

                    if !options.isEmpty {
                        Divider()
                        ForEach(options, id: \.0) { key, text in
                            optionButton(key: key, text: text, question: question)
                        }
                    }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                .padding(.horizontal)

                // 結果區（選完或查看答案後）
                if showAnswer {
                    VStack(spacing: 8) {
                        if let ans = question.correctAnswer {
                            HStack {
                                Image(systemName: selectedAnswer == ans ? "checkmark.circle.fill" : "lightbulb.fill")
                                    .foregroundStyle(selectedAnswer == ans ? .green : .yellow)
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

                    if isMultipleChoice {
                        // 選擇題：揭曉後只需「下一題」
                        Button {
                            recordAnswer(isCorrect: selectedAnswer == question.correctAnswer)
                        } label: {
                            Label("下一題", systemImage: "arrow.right.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                        .font(.headline)
                    } else {
                        // 非選擇題：自評
                        HStack(spacing: 16) {
                            Button { recordAnswer(isCorrect: false) } label: {
                                Label("答錯", systemImage: "xmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.12))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            Button { recordAnswer(isCorrect: true) } label: {
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
                    }
                } else if isMultipleChoice, let _ = selectedAnswer {
                    // 選擇題已選但未揭曉：顯示「確定」
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAnswer = true }
                    } label: {
                        Label("確定", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                } else if !isMultipleChoice {
                    // 非選擇題且未查看答案：顯示「查看答案」
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

    @ViewBuilder
    private func optionButton(key: String, text: String, question: QuestionBankItem) -> some View {
        let isCorrect = key == question.correctAnswer
        let isSelected = key == selectedAnswer
        let isEliminated = eliminatedOptions.contains(key)
        let answered = showAnswer

        let bgColor: Color = {
            if isEliminated && !answered { return Color(.systemFill).opacity(0.4) }
            guard answered else { return isSelected ? Color.blue.opacity(0.1) : Color(.systemFill) }
            if isSelected && isCorrect { return Color.green.opacity(0.2) }
            if isSelected && !isCorrect { return Color.red.opacity(0.2) }
            if isCorrect { return Color.green.opacity(0.12) }
            return Color(.systemFill)
        }()

        let keyBgColor: Color = {
            if isEliminated && !answered { return Color(.systemFill).opacity(0.4) }
            guard answered else { return isSelected ? Color.blue.opacity(0.25) : Color(.systemFill) }
            if isSelected && isCorrect { return Color.green.opacity(0.3) }
            if isSelected && !isCorrect { return Color.red.opacity(0.3) }
            if isCorrect { return Color.green.opacity(0.2) }
            return Color(.systemFill)
        }()

        let textColor: Color = {
            if isEliminated && !answered { return .secondary.opacity(0.4) }
            guard answered else { return isSelected ? .blue : .primary }
            if isSelected && isCorrect { return .green }
            if isSelected && !isCorrect { return .red }
            if isCorrect { return .green }
            return .secondary
        }()

        Button {
            guard !answered && !isEliminated else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedAnswer = (selectedAnswer == key) ? nil : key
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(key)
                    .font(.caption.bold())
                    .frame(width: 22)
                    .padding(4)
                    .background(keyBgColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .strikethrough(isEliminated && !answered, color: .secondary)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
                    .strikethrough(isEliminated && !answered, color: .secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if answered {
                    if isSelected && isCorrect {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if isSelected && !isCorrect {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    } else if isCorrect {
                        Image(systemName: "checkmark.circle").foregroundStyle(.green)
                    }
                }
            }
            .padding(8)
            .background(bgColor, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected && !answered ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(answered)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                guard !answered else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    if eliminatedOptions.contains(key) {
                        eliminatedOptions.remove(key)
                    } else {
                        eliminatedOptions.insert(key)
                        if selectedAnswer == key { selectedAnswer = nil }
                    }
                }
            }
        )
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
        session.attempts?.append(attempt)
        question.attemptCount += 1
        if isCorrect { question.correctAttemptCount += 1 }
        modelContext.insert(attempt)
        if isCorrect { session.correctCount += 1 }

        withAnimation {
            showAnswer = false
            selectedAnswer = nil
            eliminatedOptions = []
            currentIndex += 1
            if currentIndex >= questions.count {
                session.finishedAt = Date()
                try? modelContext.save()
                isFinished = true
            }
        }
    }
}
