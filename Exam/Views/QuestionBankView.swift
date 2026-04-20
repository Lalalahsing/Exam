import SwiftUI
import SwiftData

struct QuestionBankView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuestionBankItem.createdAt, order: .reverse) private var allItems: [QuestionBankItem]

    @State private var searchText = ""
    @State private var selectedSubject = "全部"
    @State private var selectedVolume = "全部"
    @State private var wrongOnly = false
    @State private var selectedItem: QuestionBankItem?

    private var subjects: [String] {
        let s = Set(allItems.map { $0.subject })
        return ["全部"] + s.sorted()
    }

    private var practicedCount: Int { allItems.filter { $0.attemptCount > 0 }.count }
    private var withErrorsCount: Int { allItems.filter { $0.errorRate > 0 || $0.firstAttemptCorrect == false }.count }

    private var filtered: [QuestionBankItem] {
        allItems.filter { item in
            let matchSubject = selectedSubject == "全部" || item.subject == selectedSubject
            let matchVolume = selectedVolume == "全部" || item.volume == selectedVolume
            let matchWrong = !wrongOnly || item.firstAttemptCorrect == false || item.errorRate > 0
            let matchSearch = searchText.isEmpty ||
                item.questionText.localizedCaseInsensitiveContains(searchText) ||
                item.chapterName.localizedCaseInsensitiveContains(searchText)
            return matchSubject && matchVolume && matchWrong && matchSearch
        }
    }

    var body: some View {
        Group {
            if allItems.isEmpty {
                ContentUnavailableView(
                    "題庫為空",
                    systemImage: "books.vertical",
                    description: Text("上傳考卷後，題目會自動加入題庫")
                )
            } else {
                List {
                    // 統計卡片
                    Section {
                        HStack(spacing: 0) {
                            StatCell(value: "\(allItems.count)", label: "總題數", color: .blue)
                            Divider().frame(height: 40)
                            StatCell(value: "\(practicedCount)", label: "已練習", color: .purple)
                            Divider().frame(height: 40)
                            StatCell(value: "\(withErrorsCount)", label: "有錯誤", color: .red)
                        }
                        .padding(.vertical, 4)
                    }

                    // 篩選列
                    Section {
                        filterRow
                    }

                    // 篩選結果數
                    Section {
                        HStack {
                            Label("共 \(filtered.count) 題", systemImage: "doc.text")
                            Spacer()
                            if wrongOnly || selectedSubject != "全部" || selectedVolume != "全部" {
                                Button("清除篩選") {
                                    selectedSubject = "全部"
                                    selectedVolume = "全部"
                                    wrongOnly = false
                                }
                                .font(.caption)
                            }
                        }
                        .font(.subheadline)
                    }

                    // 題目列表
                    ForEach(filtered) { item in
                        Button { selectedItem = item } label: {
                            QuestionBankRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            modelContext.delete(filtered[i])
                        }
                        try? modelContext.save()
                    }
                }
                .searchable(text: $searchText, prompt: "搜尋題目或章節")
            }
        }
        .navigationTitle("題庫")
        .sheet(item: $selectedItem) { item in
            QuestionDetailSheet(item: item)
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(subjects, id: \.self) { s in
                        Button(s) { selectedSubject = s }
                    }
                } label: {
                    FilterChip(title: selectedSubject == "全部" ? "科目" : selectedSubject,
                               active: selectedSubject != "全部",
                               icon: "books.vertical")
                }

                Menu {
                    Button("全部") { selectedVolume = "全部" }
                    ForEach(CurriculumData.volumes, id: \.self) { v in
                        Button(v) { selectedVolume = v }
                    }
                } label: {
                    FilterChip(title: selectedVolume == "全部" ? "冊次" : selectedVolume,
                               active: selectedVolume != "全部",
                               icon: "calendar")
                }

                Button {
                    wrongOnly.toggle()
                } label: {
                    FilterChip(title: "錯題優先", active: wrongOnly, icon: "xmark.circle")
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Row

struct QuestionBankRow: View {
    let item: QuestionBankItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SubjectBadge(subject: item.subject, style: .compact)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.questionText)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text("\(item.volume) 第\(item.chapterNum)章")
                    if let yearLabel = item.yearLabel {
                        Text(yearLabel).foregroundStyle(.blue)
                    }
                    if item.passRate >= 0 {
                        Text("通過率\(Int(item.passRate * 100))%")
                            .foregroundStyle(item.passRate >= 0.8 ? .green : item.passRate >= 0.5 ? .orange : .red)
                    }
                    // 原考結果標記
                    if let correct = item.firstAttemptCorrect {
                        Text(correct ? "原考✓" : "原考✗")
                            .foregroundStyle(correct ? .green : .red)
                    }
                    if item.attemptCount > 0 {
                        Text("練習 \(item.attemptCount) 次")
                        if item.errorRate > 0 {
                            Text("錯誤率 \(Int(item.errorRate * 100))%")
                                .foregroundStyle(item.errorRate > 0.5 ? .red : .orange)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            DifficultyBadge(difficulty: item.difficulty)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail Sheet

struct QuestionDetailSheet: View {
    let item: QuestionBankItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("題目").font(.caption.bold()).foregroundStyle(.secondary)
                        Text(item.questionText).font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    if let a = item.optionA {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("選項").font(.caption.bold()).foregroundStyle(.secondary)
                            ForEach([("A", a), ("B", item.optionB ?? ""), ("C", item.optionC ?? ""), ("D", item.optionD ?? "")].filter { !$0.1.isEmpty }, id: \.0) { key, text in
                                HStack {
                                    Text(key)
                                        .font(.caption.bold())
                                        .frame(width: 24)
                                        .padding(4)
                                        .background(key == item.correctAnswer ? Color.green.opacity(0.15) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    Text(text).font(.subheadline)
                                    if key == item.correctAnswer {
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("課綱資訊").font(.caption.bold()).foregroundStyle(.secondary)
                        if let yearLabel = item.yearLabel {
                            LabeledContent("來源", value: yearLabel)
                        }
                        LabeledContent("科目", value: item.subject)
                        LabeledContent("冊次", value: item.volume)
                        LabeledContent("章節", value: "第\(item.chapterNum)章 \(item.chapterName)")
                        LabeledContent("知識點", value: item.topic)
                        LabeledContent("難度", value: item.difficultyLabel)
                        if item.passRate >= 0 {
                            LabeledContent("全國通過率",
                                           value: String(format: "%.0f%%（%@）",
                                                         item.passRate * 100,
                                                         item.passRateLabel ?? ""))
                        }
                        if let correct = item.firstAttemptCorrect {
                            LabeledContent("原考結果", value: correct ? "✓ 答對" : "✗ 答錯")
                        }
                    }
                    .font(.subheadline)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // 解析
                    if !item.explanation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("解析", systemImage: "lightbulb.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                            Text(item.explanation)
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if item.attemptCount > 0 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("練習紀錄").font(.caption.bold()).foregroundStyle(.secondary)
                            LabeledContent("練習次數", value: "\(item.attemptCount) 次")
                            LabeledContent("錯誤率", value: String(format: "%.0f%%", item.errorRate * 100))
                        }
                        .font(.subheadline)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("題目詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Shared Components

struct FilterChip: View {
    let title: String
    let active: Bool
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(active ? Color.blue.opacity(0.15) : Color(.systemFill))
            .foregroundStyle(active ? .blue : .primary)
            .clipShape(Capsule())
    }
}

struct SubjectBadge: View {
    let subject: String
    enum Style { case compact, full }
    var style: Style = .full

    private var color: Color {
        switch subject {
        case "數學": return .blue
        case "國文": return .purple
        case "英語": return .green
        case let s where s.hasPrefix("社會"): return .orange
        case let s where s.hasPrefix("自然"): return .teal
        default: return .gray
        }
    }

    var body: some View {
        Text(style == .compact ? String(subject.prefix(2)) : subject)
            .font(.caption.bold())
            .padding(.horizontal, style == .compact ? 6 : 10)
            .padding(.vertical, style == .compact ? 4 : 5)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct DifficultyBadge: View {
    let difficulty: String

    private var label: String {
        switch difficulty {
        case "easy": return "基礎"
        case "medium": return "一般"
        case "hard": return "進階"
        default: return difficulty
        }
    }

    private var color: Color {
        switch difficulty {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
