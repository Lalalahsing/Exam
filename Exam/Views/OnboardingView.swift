import SwiftUI

struct OnboardingView: View {
    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @State private var inputKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // 標題區
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 72))
                            .foregroundStyle(.blue)
                        Text("國中會考分析系統")
                            .font(.largeTitle.bold())
                        Text("AI 智慧分析考卷・精準掌握學習狀況")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // 功能說明
                    VStack(spacing: 16) {
                        FeatureRow(icon: "camera.fill", color: .blue,
                                   title: "拍照上傳考卷",
                                   desc: "AI 自動辨識每道題目與答案")
                        FeatureRow(icon: "books.vertical.fill", color: .green,
                                   title: "智慧題庫管理",
                                   desc: "自動對應 108 課綱章節")
                        FeatureRow(icon: "pencil.and.list.clipboard", color: .orange,
                                   title: "加權練習模式",
                                   desc: "弱點優先，高效複習")
                        FeatureRow(icon: "chart.bar.fill", color: .purple,
                                   title: "學習成效追蹤",
                                   desc: "章節熱圖一目瞭然")
                    }
                    .padding(.horizontal)

                    // API Key 輸入
                    VStack(alignment: .leading, spacing: 12) {
                        Text("設定 Anthropic API Key")
                            .font(.headline)
                        Text("請前往 console.anthropic.com 申請 API Key，貼上後即可開始使用。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        SecureField("sk-ant-...", text: $inputKey)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))

                        if let error = errorMessage {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button {
                            saveKey()
                        } label: {
                            Group {
                                if isValidating {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("開始使用")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(inputKey.hasPrefix("sk-ant") ? Color.blue : Color.gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(inputKey.count < 10 || isValidating)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func saveKey() {
        let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "請輸入 API Key"
            return
        }
        apiKey = trimmed
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
