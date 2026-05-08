import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @Query(sort: \Exam.createdAt, order: .reverse) private var exams: [Exam]

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showUploadSheet = false
    @State private var showAPIKeyPrompt = false
    @State private var navigateToResult: Exam?

    var body: some View {
        List {
            // 上傳區
            Section {
                uploadCard
            }

            // 分析中提示
            if isAnalyzing {
                Section {
                    HStack(spacing: 12) {
                        ProgressView().progressViewStyle(.circular)
                        VStack(alignment: .leading) {
                            Text("AI 分析中…").fontWeight(.medium)
                            Text("正在辨識題目與課綱對應").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // 錯誤訊息
            if let error = analysisError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            // 考試記錄
            if !exams.isEmpty {
                Section("考試記錄") {
                    ForEach(exams) { exam in
                        NavigationLink(value: exam) {
                            ExamRowView(exam: exam)
                        }
                    }
                    .onDelete(perform: deleteExams)
                }
            } else if !isAnalyzing {
                Section {
                    ContentUnavailableView(
                        "尚無考試記錄",
                        systemImage: "doc.text",
                        description: Text("點選上方按鈕拍攝或上傳考卷")
                    )
                }
            }
        }
        .navigationTitle("國中會考分析")
        .navigationDestination(for: Exam.self) { exam in
            ExamResultView(exam: exam)
        }
        .sheet(isPresented: $showUploadSheet) {
            uploadOptionsSheet
        }
        .sheet(isPresented: $showAPIKeyPrompt) {
            APIKeyPromptSheet(isPresented: $showAPIKeyPrompt)
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                selectedPhotoItems = []
                if !images.isEmpty { await analyzeImages(images) }
            }
        }
    }

    // MARK: - Upload Card

    private var uploadCard: some View {
        Button {
            if apiKey.isEmpty {
                showAPIKeyPrompt = true
            } else {
                showUploadSheet = true
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("上傳考卷")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("拍照或從相簿選擇")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .disabled(isAnalyzing)
    }

    // MARK: - Upload Options Sheet

    private var uploadOptionsSheet: some View {
        NavigationStack {
            List {
                Section {
                    // 相機拍照
                    Label("拍照", systemImage: "camera.fill")
                        .onTapGesture {
                            showUploadSheet = false
                            showCamera = true
                        }

                    // 相簿選擇（可多選）
                    PhotosPicker(selection: $selectedPhotoItems,
                                 maxSelectionCount: 10,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        Label("從相簿選擇（可多張）", systemImage: "photo.on.rectangle.angled")
                    }
                    .simultaneousGesture(TapGesture().onEnded { showUploadSheet = false })
                }
            }
            .navigationTitle("選擇圖片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showUploadSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Analysis

    @MainActor
    private func analyzeImages(_ images: [UIImage]) async {
        isAnalyzing = true
        analysisError = nil
        do {
            let imageDatas: [Data] = images.compactMap { $0.resizedForUpload().jpegData(compressionQuality: 0.85) }
            guard !imageDatas.isEmpty else {
                analysisError = "圖片編碼失敗"
                isAnalyzing = false
                return
            }
            let result = try await AnthropicService.shared.analyzeExam(imageDatas: imageDatas, apiKey: apiKey)
            // 儲存所有頁面圖片
            let pageNames: [String] = images.enumerated().map { i, img in
                let name = UUID().uuidString + "_p\(i).jpg"
                saveImageWithName(img, name: name)
                return name
            }
            let imageName = pageNames.first ?? saveImage(images[0])
            let exam = Exam(
                subject: result.subject,
                imageName: imageName,
                rawJson: (try? String(data: JSONEncoder().encode(result), encoding: .utf8)) ?? "",
                notes: result.notes ?? "",
                pageImageNames: pageNames
            )
            modelContext.insert(exam)

            for q in result.questions {
                // 裁切圖形（若有）
                let figName: String? = {
                    guard let region = q.figureRegion,
                          region.page < images.count,
                          region.width > 0.01, region.height > 0.01 else { return nil }
                    return saveCroppedFigure(from: images[region.page], region: region)
                }()

                // 編碼表格（若有）
                let tableJsonStr: String? = {
                    guard let td = q.tableData else { return nil }
                    return (try? String(data: JSONEncoder().encode(td), encoding: .utf8)) ?? nil
                }()

                let eq = ExamQuestion(
                    number: q.number,
                    questionText: q.questionText,
                    questionType: q.questionType,
                    optionA: q.options?["A"],
                    optionB: q.options?["B"],
                    optionC: q.options?["C"],
                    optionD: q.options?["D"],
                    correctAnswer: q.correctAnswer,
                    studentAnswer: q.studentAnswer,
                    isCorrect: q.isCorrect,
                    volume: q.volume,
                    chapterNum: q.chapterNum,
                    chapterName: q.chapterName,
                    topic: q.topic,
                    difficulty: q.difficulty,
                    confidence: q.confidence,
                    groupId: q.groupId,
                    groupPremise: q.groupPremise,
                    groupOrder: q.groupOrder,
                    figureImageName: figName,
                    tableJson: tableJsonStr
                )
                eq.exam = exam
                exam.questions?.append(eq)

                // 同步存入題庫
                let bankItem = QuestionBankItem(
                    sourceExamId: exam.id,
                    subject: result.subject,
                    volume: q.volume,
                    chapterNum: q.chapterNum,
                    chapterName: q.chapterName,
                    topic: q.topic,
                    questionNum: q.number,
                    questionText: q.questionText,
                    questionType: q.questionType,
                    optionA: q.options?["A"],
                    optionB: q.options?["B"],
                    optionC: q.options?["C"],
                    optionD: q.options?["D"],
                    correctAnswer: q.correctAnswer,
                    difficulty: q.difficulty,
                    firstAttemptCorrect: q.isCorrect,
                    groupId: q.groupId,
                    groupPremise: q.groupPremise,
                    groupOrder: q.groupOrder,
                    figureImageName: figName,
                    tableJson: tableJsonStr
                )
                modelContext.insert(bankItem)
            }
            try? modelContext.save()
            navigateToResult = exam
        } catch {
            analysisError = error.localizedDescription
        }
        isAnalyzing = false
    }

    private func saveImage(_ image: UIImage) -> String {
        let name = UUID().uuidString + ".jpg"
        if let data = image.jpegData(compressionQuality: 0.85) {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(name)
            try? data.write(to: url)
        }
        return name
    }

    /// 儲存圖片並指定檔名
    @discardableResult
    private func saveImageWithName(_ image: UIImage, name: String) -> String {
        if let data = image.jpegData(compressionQuality: 0.88) {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(name)
            try? data.write(to: url)
        }
        return name
    }

    /// 依 FigureRegion 裁切圖片，儲存並回傳檔名；失敗回傳 nil
    private func saveCroppedFigure(from image: UIImage, region: FigureRegion) -> String? {
        // 先 normalize 方向
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let normalized = renderer.image { _ in image.draw(at: .zero) }
        let w = normalized.size.width
        let h = normalized.size.height
        // 加 5% padding，避免裁太緊
        let pad = 0.05
        let rx = max(0, region.x - pad) * w
        let ry = max(0, region.y - pad) * h
        let rw = min(1, region.x + region.width  + pad) * w - rx
        let rh = min(1, region.y + region.height + pad) * h - ry
        guard rw > 10, rh > 10 else { return nil }
        let rect = CGRect(x: rx, y: ry, width: rw, height: rh)
        guard let cgCropped = normalized.cgImage?.cropping(to: rect) else { return nil }
        let cropped = UIImage(cgImage: cgCropped)
        let name = UUID().uuidString + "_fig.jpg"
        if let data = cropped.jpegData(compressionQuality: 0.9) {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(name)
            try? data.write(to: url)
            return name
        }
        return nil
    }

    private func deleteExams(at offsets: IndexSet) {
        for index in offsets {
            let exam = exams[index]
            // 刪除對應圖片
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(exam.imageName)
            try? FileManager.default.removeItem(at: url)
            modelContext.delete(exam)
        }
        try? modelContext.save()
    }
}

// MARK: - Exam Row

struct ExamRowView: View {
    let exam: Exam

    var body: some View {
        HStack(spacing: 12) {
            SubjectBadge(subject: exam.subject, style: .compact)
            VStack(alignment: .leading, spacing: 4) {
                Text(exam.subject)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Text("\((exam.questions ?? []).count) 題")
                    if exam.totalAnswered > 0 {
                        Text("答對 \(exam.correctCount)/\(exam.totalAnswered)")
                            .foregroundStyle(exam.accuracyRate >= 0.8 ? .green : exam.accuracyRate >= 0.6 ? .orange : .red)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(exam.createdAt.formatted(.dateTime.month().day()))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}


// MARK: - API Key 提示 Sheet

struct APIKeyPromptSheet: View {
    @Binding var isPresented: Bool
    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @State private var inputKey = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    Text("需要 API Key")
                        .font(.title2.bold())
                    Text("AI 辨識功能需要 Anthropic API Key。\n請前往 console.anthropic.com 取得。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                SecureField("sk-ant-...", text: $inputKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal)

                Button {
                    let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    apiKey = trimmed
                    isPresented = false
                } label: {
                    Text("儲存並繼續")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(inputKey.hasPrefix("sk-ant") ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(inputKey.count < 10)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - UIImage 縮圖（@MainActor 安全，在此呼叫端處理 UIKit）
extension UIImage {
    func resizedForUpload(maxDimension: CGFloat = 1600) -> UIImage {
        let size = self.size
        guard size.width > maxDimension || size.height > maxDimension else { return self }
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
