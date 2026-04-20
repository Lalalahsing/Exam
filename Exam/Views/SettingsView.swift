import SwiftUI

struct SettingsView: View {
    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @State private var inputKey = ""
    @State private var showResetAlert = false
    @State private var keySaved = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Anthropic API Key")
                        .font(.subheadline.bold())
                    SecureField("sk-ant-...", text: $inputKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                    if !apiKey.isEmpty {
                        Text("目前已設定：\(maskedKey)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                Button {
                    let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    apiKey = trimmed
                    inputKey = ""
                    keySaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { keySaved = false }
                } label: {
                    Label(keySaved ? "已儲存！" : "儲存 API Key",
                          systemImage: keySaved ? "checkmark.circle.fill" : "key.fill")
                        .foregroundStyle(keySaved ? .green : .blue)
                }
                .disabled(inputKey.count < 10)
            } header: {
                Text("API 設定")
            } footer: {
                Text("前往 console.anthropic.com 建立 API Key。Key 儲存在裝置本機，不會上傳至任何伺服器。")
            }

            Section("關於") {
                LabeledContent("版本", value: "1.0.0")
                LabeledContent("AI 模型", value: "Claude Sonnet 4.6")
                LabeledContent("課綱版本", value: "108 課綱")
            }

            Section {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label("清除 API Key", systemImage: "trash")
                }
            }

        }
        .navigationTitle("設定")
        .alert("確認清除", isPresented: $showResetAlert) {
            Button("清除", role: .destructive) { apiKey = "" }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清除後需重新輸入 API Key 才能使用 AI 分析功能。")
        }
    }

    private var maskedKey: String {
        guard apiKey.count > 8 else { return "****" }
        let prefix = String(apiKey.prefix(10))
        return "\(prefix)...****"
    }
}
