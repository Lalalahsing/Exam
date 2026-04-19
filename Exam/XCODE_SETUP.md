# Xcode 專案設定步驟

## 1. 建立新專案

1. 開啟 Xcode → File > New > Project
2. 選擇 **iOS > App**
3. 填入以下資訊：
   - Product Name: `ExamAnalyzer`
   - Bundle Identifier: `com.yourname.examanalyzer`（可自訂）
   - Interface: **SwiftUI**
   - Storage: **None**（我們自己管理 SwiftData）
   - Language: **Swift**
4. 儲存位置選 `~/Desktop/Code/`，命名為 `ExamAnalyzerXcode`

## 2. 刪除 Xcode 自動生成的檔案

刪除以下 Xcode 預設生成的檔案：
- `ContentView.swift`
- `ExamAnalyzerApp.swift`（之後會替換）

## 3. 加入原始碼

將 `ExamAnalyzerIOS/` 內的所有 Swift 檔案加入專案：

1. 在 Xcode Project Navigator 右鍵 → Add Files to "ExamAnalyzer"
2. 選取以下所有檔案（可以全選）：
   - `ExamAnalyzerApp.swift`
   - `RootView.swift`
   - `Models/Exam.swift`
   - `Models/QuestionBankItem.swift`
   - `Models/PracticeSession.swift`
   - `Services/AnthropicService.swift`
   - `Services/CurriculumData.swift`
   - `Services/WeightingService.swift`
   - `Views/OnboardingView.swift`
   - `Views/HomeView.swift`
   - `Views/ExamResultView.swift`
   - `Views/QuestionBankView.swift`
   - `Views/PracticeSetupView.swift`
   - `Views/PracticeSessionView.swift`
   - `Views/PracticeResultView.swift`
   - `Views/DashboardView.swift`
   - `Views/SettingsView.swift`
3. 勾選 **Copy items if needed**，點 Add

## 4. 設定 Info.plist 權限

在 Project Settings → Info → Custom iOS Target Properties 加入：

| Key | Value |
|-----|-------|
| NSCameraUsageDescription | 需要相機權限以拍攝考卷 |
| NSPhotoLibraryUsageDescription | 需要相簿權限以選擇考卷圖片 |

## 5. 部署目標設定

- General → Minimum Deployments → **iOS 26.0**

## 6. 加入 Charts Framework（若未自動包含）

Swift Charts 已內建於 iOS 16+ 無需額外操作。

## 7. 執行

選擇模擬器（iPhone 16 Pro 或 iPad Pro）→ 按 ▶ 執行

首次啟動會顯示引導畫面，貼入 Anthropic API Key 後即可使用。

---

## 功能說明

| Tab | 功能 |
|-----|------|
| 首頁 | 上傳考卷（相機/相簿），查看歷史記錄 |
| 題庫 | 瀏覽所有題目，支援科目/冊次/錯題篩選 |
| 練習 | 設定練習範圍，加權智慧抽題 |
| 成效 | 各科正確率圖表、練習趨勢、章節熱圖 |
| 設定 | 管理 API Key |
