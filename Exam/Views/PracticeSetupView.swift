import SwiftUI
import SwiftData

struct PracticeSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [QuestionBankItem]

    @State private var selectedSubject = "全部"
    @State private var selectedVolume = "全部"
    @State private var selectedYear = 0       // 0 = 全部
    @State private var questionCount = 10
    @State private var navigateToSession: PracticeSessionConfig?

    private var availableSubjects: [String] {
        let s = Set(allItems.map { $0.subject })
        return ["全部"] + s.sorted()
    }

    /// 題庫中有資料的年份，由新到舊排列
    private var availableYears: [Int] {
        let years = Set(allItems.map { $0.year }.filter { $0 > 0 })
        return years.sorted(by: >)
    }

    private var poolCount: Int {
        let filtered = allItems.filter { item in
            let matchSub  = selectedSubject == "全部" || item.subject == selectedSubject
            let matchVol  = selectedVolume  == "全部" || item.volume  == selectedVolume
            let matchYear = selectedYear == 0         || item.year    == selectedYear
            return matchSub && matchVol && matchYear
        }
        let groupIds = Set(filtered.compactMap { $0.groupId }.filter { !$0.isEmpty })
        let standaloneCount = filtered.filter { ($0.groupId ?? "").isEmpty }.count
        return standaloneCount + groupIds.count
    }

    var body: some View {
        Form {
            Section("練習範圍") {
                Picker("科目", selection: $selectedSubject) {
                    ForEach(availableSubjects, id: \.self) { Text($0).tag($0) }
                }
                Picker("冊次", selection: $selectedVolume) {
                    Text("全部").tag("全部")
                    ForEach(CurriculumData.volumes, id: \.self) { Text($0).tag($0) }
                }
                Picker("年份", selection: $selectedYear) {
                    Text("全部").tag(0)
                    ForEach(availableYears, id: \.self) { year in
                        Text("\(year) 年會考").tag(year)
                    }
                }
                .disabled(availableYears.isEmpty)
            }

            Section {
                let upper = max(1, min(poolCount, 50))
                let safeCount = max(1, min(questionCount, upper))
                Stepper("題數：\(safeCount) 題",
                        value: Binding(get: { safeCount }, set: { questionCount = $0 }),
                        in: 1...upper, step: 5)
                    .disabled(poolCount == 0)
            } header: {
                Text("出題數量")
            } footer: {
                Text("題庫中符合條件的共 \(poolCount) 組/題，依加權演算法抽取（錯誤率高的題目優先出現）")
            }

            Section("演算法說明") {
                VStack(alignment: .leading, spacing: 10) {
                    WeightRow(color: .gray,   label: "未練習過",   weight: "55",     desc: "首次接觸，高曝光率")
                    WeightRow(color: .red,    label: "有錯誤記錄", weight: "20~100", desc: "錯誤率越高權重越大")
                    WeightRow(color: .orange, label: "原本答錯",   weight: "+15",    desc: "考卷答錯額外加權")
                    WeightRow(color: .green,  label: "完全答對",   weight: "10",     desc: "已熟練，輕量複習")
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    guard poolCount > 0 else { return }
                    let upper = max(1, min(poolCount, 50))
                    navigateToSession = PracticeSessionConfig(
                        subject: selectedSubject,
                        volume: selectedVolume == "全部" ? nil : selectedVolume,
                        year: selectedYear == 0 ? nil : selectedYear,
                        count: max(1, min(questionCount, upper))
                    )
                } label: {
                    Label("開始練習", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(poolCount == 0)
            }
        }
        .navigationTitle("練習設定")
        .navigationDestination(item: $navigateToSession) { config in
            PracticeSessionView(config: config)
        }
    }
}

struct PracticeSessionConfig: Hashable, Identifiable {
    let id = UUID()
    let subject: String
    let volume: String?
    let year: Int?        // nil = 不限年份
    let count: Int
}

private struct WeightRow: View {
    let color: Color
    let label: String
    let weight: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10).padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label).font(.subheadline.bold())
                    Spacer()
                    Text("權重 \(weight)").font(.caption.bold()).foregroundStyle(color)
                }
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
