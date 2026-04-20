# 國中會考分析系統

iOS App，整合 AI 考卷辨識、歷屆題庫、練習模式與 iCloud 同步。

## 功能

| Tab | 說明 |
|-----|------|
| 首頁 | 拍照或從相簿上傳考卷，AI 自動辨識題目、對應課綱章節 |
| 題庫 | 瀏覽 2157 題歷屆會考題目（103–113 年），支援科目／冊次／錯題篩選 |
| 練習 | 加權抽題（錯題優先），即時批改 |
| 成效 | 各科正確率、練習趨勢折線圖、章節熱圖 |
| 設定 | 管理 Anthropic API Key |

### 歷屆題庫

- 涵蓋 104–113 年國中教育會考（103 年為掃描版，無法解析）
- 每題附：全國通過率、正確答案、課綱章節對應、難度分級
- 首次啟動自動匯入；更新 `exam_data.db` 後重新 Build 即自動刷新

### iCloud 同步

- 練習紀錄、考卷分析結果透過 **CloudKit** 跨裝置同步
- API Key 透過 **iCloud Key-Value Store** 同步，只需在一台裝置輸入

### AI 辨識

- 使用 Anthropic Claude（需自備 API Key）
- 第一次點「上傳考卷」時才要求輸入，不影響題庫與練習功能

## 開發環境

- Xcode 16+
- iOS 26.0+
- Swift 5.0

## 設定步驟

### 1. Clone 並開啟專案

```bash
git clone https://github.com/Lalalahsing/Exam.git
cd Exam
open Exam.xcodeproj
```

### 2. 啟用 iCloud 功能

Xcode → 選擇 Exam target → **Signing & Capabilities** → **+** → 加入 **iCloud**

勾選：
- ☑ Key-value storage
- ☑ CloudKit → 選擇 container `iCloud.lalala.Exam`

> 此步驟會在 Apple Developer Portal 自動建立 CloudKit container，少了這步 App 會退回本地儲存模式。

### 3. 設定 Bundle Identifier 與 Team

General → 修改 Bundle Identifier 與 Team 為自己的帳號。

### 4. 執行

選擇模擬器或實機 → ▶

首頁可直接瀏覽題庫與練習；需要 AI 辨識時才輸入 Anthropic API Key。

## 更新題庫

```bash
cd scripts
python3 build_default_db.py        # 重新爬取並解析所有年份
cp output/exam_data.db ../exam_data.db
```

重新 Build App 後，啟動時自動偵測檔案變更並重新匯入。

## 專案結構

```
Exam/
├── Models/
│   ├── Exam.swift              # 考卷與題目 Model
│   ├── QuestionBankItem.swift  # 題庫 Model
│   └── PracticeSession.swift   # 練習紀錄 Model
├── Services/
│   ├── AnthropicService.swift  # Claude API 呼叫
│   ├── AppSettings.swift       # iCloud KV Store 同步
│   ├── DatabaseMigrator.swift  # SQLite → SwiftData 遷移
│   ├── CurriculumData.swift    # 108 課綱章節資料
│   └── WeightingService.swift  # 加權抽題邏輯
├── Views/                      # 各畫面
├── ExamAnalyzerApp.swift       # App 進入點，CloudKit container 設定
└── Exam.entitlements           # iCloud 權限宣告

exam_data.db                    # 內建歷屆題庫（103–113 年，2157 題）
scripts/
└── build_default_db.py         # 題庫建置腳本
```
