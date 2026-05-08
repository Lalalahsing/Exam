import SwiftUI
import SwiftData

struct PracticeSessionView: View {
    let config: PracticeSessionConfig
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allItems: [QuestionBankItem]

    @State private var session: PracticeSession?
    @State private var units: [QuestionUnit] = []
    @State private var currentUnitIndex = 0
    @State private var showAnswer = false
    @State private var selectedAnswers: [UUID: String] = [:]
    @State private var eliminatedOptions: [UUID: Set<String>] = [:]
    @State private var isFinished = false
    @State private var showExitAlert = false

    private var currentUnit: QuestionUnit? {
        guard currentUnitIndex < units.count else { return nil }
        return units[currentUnitIndex]
    }

    var body: some View {
        Group {
            if isFinished, let session {
                PracticeResultView(session: session)
            } else if let unit = currentUnit {
                unitCard(unit: unit)
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
                if !units.isEmpty {
                    Text("\(currentUnitIndex + 1) / \(units.count)")
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

    // MARK: - Unit Card Dispatcher

    @ViewBuilder
    private func unitCard(unit: QuestionUnit) -> some View {
        switch unit {
        case .single(let q):
            singleCard(question: q)
        case .group(_, let premise, let questions):
            groupCard(premise: premise, questions: questions)
        }
    }

    // MARK: - Single Question Card

    @ViewBuilder
    private func singleCard(question: QuestionBankItem) -> some View {
        let isMultipleChoice = question.optionA != nil
        let options = optionPairs(for: question)
        let sel = selectedAnswers[question.id]
        let elim = eliminatedOptions[question.id, default: []]

        ScrollView {
            VStack(spacing: 20) {
                ProgressView(value: Double(currentUnitIndex), total: Double(units.count))
                    .padding(.horizontal)

                HStack {
                    SubjectBadge(subject: question.subject, style: .full)
                    Text("\(question.volume) 第\(question.chapterNum)章")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    DifficultyBadge(difficulty: question.difficulty)
                }
                .padding(.horizontal)

                questionCard(question: question, options: options,
                             selectedAnswer: sel, eliminatedOptions: elim,
                             showAnswer: showAnswer)

                bottomControls(
                    isMultipleChoice: isMultipleChoice,
                    allAnswered: sel != nil,
                    onConfirm: { withAnimation(.easeInOut(duration: 0.2)) { showAnswer = true } },
                    onNext: { recordCurrentUnit() },
                    onCorrect: { recordCurrentUnit(overrideCorrect: true) },
                    onWrong: { recordCurrentUnit(overrideCorrect: false) }
                )

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Group Card

    @ViewBuilder
    private func groupCard(premise: String, questions: [QuestionBankItem]) -> some View {
        let allMCAnswered = questions.filter { $0.optionA != nil }
            .allSatisfy { selectedAnswers[$0.id] != nil }

        ScrollView {
            VStack(spacing: 16) {
                ProgressView(value: Double(currentUnitIndex), total: Double(units.count))
                    .padding(.horizontal)

                // 題組前提
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.quote")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.teal, in: RoundedRectangle(cornerRadius: 6))
                        Text("題組前提")
                            .font(.caption.bold())
                            .foregroundStyle(.teal)
                    }
                    Text(premise)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.teal.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal)

                // 各小題
                ForEach(questions) { q in
                    let options = optionPairs(for: q)
                    let sel = selectedAnswers[q.id]
                    let elim = eliminatedOptions[q.id, default: []]

                    VStack(spacing: 12) {
                        HStack {
                            Text("第 \(q.questionNum) 題")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            Spacer()
                            DifficultyBadge(difficulty: q.difficulty)
                        }
                        questionCard(question: q, options: options,
                                     selectedAnswer: sel, eliminatedOptions: elim,
                                     showAnswer: showAnswer)
                    }
                    .padding(.horizontal)
                }

                // 底部控制
                if showAnswer {
                    Button { recordCurrentUnit() } label: {
                        Label("下一題", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .font(.headline)
                } else if allMCAnswered && !questions.filter({ $0.optionA != nil }).isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAnswer = true }
                    } label: {
                        Label("確定", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                } else if questions.allSatisfy({ $0.optionA == nil }) {
                    // 全是非選擇題
                    if showAnswer {
                        HStack(spacing: 16) {
                            Button { recordCurrentUnit(overrideCorrect: false) } label: {
                                Label("答錯", systemImage: "xmark.circle.fill")
                                    .frame(maxWidth: .infinity).padding()
                                    .background(Color.red.opacity(0.12))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            Button { recordCurrentUnit(overrideCorrect: true) } label: {
                                Label("答對", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity).padding()
                                    .background(Color.green.opacity(0.12))
                                    .foregroundStyle(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal).font(.headline)
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { showAnswer = true }
                        } label: {
                            Label("查看答案", systemImage: "eye.fill")
                                .frame(maxWidth: .infinity).padding()
                        }
                        .buttonStyle(.borderedProminent).padding(.horizontal)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Question Card (shared)

    @ViewBuilder
    private func questionCard(
        question: QuestionBankItem,
        options: [(String, String)],
        selectedAnswer: String?,
        eliminatedOptions: Set<String>,
        showAnswer: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 圖形（若有）
            if let figName = question.figureImageName {
                FigureImageView(imageName: figName)
            }
            // 表格（若有）
            if let table = question.decodedTable {
                QuestionTableView(table: table)
            }
            Text(question.questionText)
                .font(.body)

            if !options.isEmpty {
                Divider()
                ForEach(options, id: \.0) { key, text in
                    optionButton(
                        key: key, text: text,
                        questionId: question.id,
                        correctAnswer: question.correctAnswer,
                        selectedAnswer: selectedAnswer,
                        eliminatedOptions: eliminatedOptions,
                        answered: showAnswer
                    )
                }
            }

            // 揭曉後的答案說明
            if showAnswer {
                Divider()
                HStack(spacing: 6) {
                    if let ans = question.correctAnswer {
                        Image(systemName: selectedAnswer == ans ? "checkmark.circle.fill" : "lightbulb.fill")
                            .foregroundStyle(selectedAnswer == ans ? .green : .yellow)
                        Text("正確答案：\(ans)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Text(question.topic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Option Button

    @ViewBuilder
    private func optionButton(
        key: String,
        text: String,
        questionId: UUID,
        correctAnswer: String?,
        selectedAnswer: String?,
        eliminatedOptions: Set<String>,
        answered: Bool
    ) -> some View {
        let isCorrect = key == correctAnswer
        let isSelected = key == selectedAnswer
        let isEliminated = eliminatedOptions.contains(key)

        let bgColor: Color = {
            if isEliminated && !answered { return Color(.systemFill).opacity(0.4) }
            guard answered else { return isSelected ? Color.blue.opacity(0.1) : Color(.systemFill) }
            if isSelected && isCorrect  { return Color.green.opacity(0.2) }
            if isSelected && !isCorrect { return Color.red.opacity(0.2) }
            if isCorrect                { return Color.green.opacity(0.12) }
            return Color(.systemFill)
        }()

        let keyBg: Color = {
            if isEliminated && !answered { return Color(.systemFill).opacity(0.4) }
            guard answered else { return isSelected ? Color.blue.opacity(0.25) : Color(.systemFill) }
            if isSelected && isCorrect  { return Color.green.opacity(0.3) }
            if isSelected && !isCorrect { return Color.red.opacity(0.3) }
            if isCorrect                { return Color.green.opacity(0.2) }
            return Color(.systemFill)
        }()

        let textColor: Color = {
            if isEliminated && !answered { return Color.secondary.opacity(0.4) }
            guard answered else { return isSelected ? .blue : .primary }
            if isSelected && isCorrect  { return .green }
            if isSelected && !isCorrect { return .red }
            if isCorrect                { return .green }
            return .secondary
        }()

        Button {
            guard !answered && !isEliminated else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                let current = self.selectedAnswers[questionId]
                self.selectedAnswers[questionId] = (current == key) ? nil : key
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(key)
                    .font(.caption.bold())
                    .frame(width: 22)
                    .padding(4)
                    .background(keyBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .strikethrough(isEliminated && !answered, color: .secondary)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
                    .strikethrough(isEliminated && !answered, color: Color.secondary.opacity(0.6))
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
                    .stroke(isSelected && !answered ? Color.blue.opacity(0.5) : Color.clear,
                            lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(answered)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                guard !answered else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    if self.eliminatedOptions[questionId, default: []].contains(key) {
                        self.eliminatedOptions[questionId]?.remove(key)
                    } else {
                        self.eliminatedOptions[questionId, default: []].insert(key)
                        if self.selectedAnswers[questionId] == key {
                            self.selectedAnswers[questionId] = nil
                        }
                    }
                }
            }
        )
    }

    // MARK: - Bottom Controls (single question)

    @ViewBuilder
    private func bottomControls(
        isMultipleChoice: Bool,
        allAnswered: Bool,
        onConfirm: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onCorrect: @escaping () -> Void,
        onWrong: @escaping () -> Void
    ) -> some View {
        if showAnswer {
            if isMultipleChoice {
                Button(action: onNext) {
                    Label("下一題", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .font(.headline)
            } else {
                HStack(spacing: 16) {
                    Button(action: onWrong) {
                        Label("答錯", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button(action: onCorrect) {
                        Label("答對", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.green.opacity(0.12))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal).font(.headline)
            }
        } else if isMultipleChoice && allAnswered {
            Button(action: onConfirm) {
                Label("確定", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity).padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        } else if !isMultipleChoice {
            Button(action: onConfirm) {
                Label("查看答案", systemImage: "eye.fill")
                    .frame(maxWidth: .infinity).padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func optionPairs(for question: QuestionBankItem) -> [(String, String)] {
        [("A", question.optionA), ("B", question.optionB),
         ("C", question.optionC), ("D", question.optionD)]
            .compactMap { key, val -> (String, String)? in
                guard let v = val, !v.isEmpty else { return nil }
                return (key, v)
            }
    }

    // MARK: - Logic


    private func setupSession() {
        let pool = allItems.filter { item in
            let matchSub  = config.subject == "全部" || item.subject == config.subject
            let matchVol  = config.volume == nil     || item.volume  == config.volume
            let matchYear = config.year   == nil     || item.year    == config.year
            return matchSub && matchVol && matchYear
        }
        units = WeightingService.selectUnits(from: pool, count: config.count)
        let totalQ = units.reduce(0) { $0 + $1.questions.count }
        let s = PracticeSession(
            subject: config.subject,
            volumeFilter: config.volume,
            questionCount: totalQ
        )
        modelContext.insert(s)
        session = s
    }

    /// overrideCorrect：nil = 依據 selectedAnswers 判斷（MC）；非 nil = 非選題自評
    private func recordCurrentUnit(overrideCorrect: Bool? = nil) {
        guard let unit = currentUnit, let session else { return }

        for question in unit.questions {
            let isCorrect: Bool
            if let override = overrideCorrect {
                isCorrect = override
            } else {
                let ans = selectedAnswers[question.id]
                isCorrect = ans != nil && ans == question.correctAnswer
            }
            question.attemptCount += 1
            if isCorrect { question.correctAttemptCount += 1 }
            let attempt = PracticeAttempt(questionId: question.id, isCorrect: isCorrect)
            attempt.session = session
            session.attempts?.append(attempt)
            modelContext.insert(attempt)
            if isCorrect { session.correctCount += 1 }
        }

        withAnimation {
            showAnswer = false
            selectedAnswers = [:]
            eliminatedOptions = [:]
            currentUnitIndex += 1
            if currentUnitIndex >= units.count {
                session.finishedAt = Date()
                try? modelContext.save()
                isFinished = true
            }
        }
    }
}

// MARK: - Figure Image View

struct FigureImageView: View {
    let imageName: String
    @State private var showFullscreen = false

    private var imageURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(imageName)
    }

    var body: some View {
        if let url = imageURL,
           let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .onTapGesture { showFullscreen = true }
                .fullScreenCover(isPresented: $showFullscreen) {
                    FullscreenImageView(uiImage: uiImage, onDismiss: { showFullscreen = false })
                }
        }
    }
}

struct FullscreenImageView: View {
    let uiImage: UIImage
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: geo.size.width * max(scale, 1),
                            height: geo.size.height * max(scale, 1)
                        )
                }
            }
            .background(Color.black)
            .gesture(MagnificationGesture()
                .onChanged { v in scale = v }
                .onEnded { _ in if scale < 1 { withAnimation { scale = 1 } } }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { onDismiss() }
                }
            }
        }
    }
}
