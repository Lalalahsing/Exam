import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @Query(sort: \Exam.createdAt, order: .reverse) private var exams: [Exam]

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showUploadSheet = false
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
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    await analyzeImage(image)
                }
            }
        }
    }

    // MARK: - Upload Card

    private var uploadCard: some View {
        Button {
            showUploadSheet = true
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

                    // 相簿選擇
                    PhotosPicker(selection: $selectedPhotoItem,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        Label("從相簿選擇", systemImage: "photo.on.rectangle.angled")
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
    private func analyzeImage(_ image: UIImage) async {
        isAnalyzing = true
        analysisError = nil
        do {
            // UIImage 操作在 @MainActor 完成，只傳 Data 給 service（Swift 6 安全）
            let resized = image.resizedForUpload()
            guard let imageData = resized.jpegData(compressionQuality: 0.85) else {
                analysisError = "圖片編碼失敗"
                isAnalyzing = false
                return
            }
            let result = try await AnthropicService.shared.analyzeExam(imageData: imageData, apiKey: apiKey)
            let imageName = saveImage(image)
            let exam = Exam(
                subject: result.subject,
                imageName: imageName,
                rawJson: (try? String(data: JSONEncoder().encode(result), encoding: .utf8)) ?? "",
                notes: result.notes ?? ""
            )
            modelContext.insert(exam)

            for q in result.questions {
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
                    confidence: q.confidence
                )
                eq.exam = exam
                exam.questions.append(eq)

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
                    firstAttemptCorrect: q.isCorrect
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
                    Text("\(exam.questions.count) 題")
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
