import Foundation

// MARK: - API Response Models（全部標記 Sendable 以符合 Swift 6 並發規則）

struct ExamAnalysisResponse: Codable, Sendable {
    let subject: String
    let questions: [QuestionData]
    let notes: String?
}

struct QuestionData: Codable, Sendable {
    let number: Int
    let questionText: String
    let questionType: String
    let options: [String: String]?
    let correctAnswer: String?
    let studentAnswer: String?
    let isCorrect: Bool?
    let volume: String
    let chapterNum: Int
    let chapterName: String
    let topic: String
    let difficulty: String
    let confidence: String

    enum CodingKeys: String, CodingKey {
        case number
        case questionText = "question_text"
        case questionType = "question_type"
        case options
        case correctAnswer = "correct_answer"
        case studentAnswer = "student_answer"
        case isCorrect = "is_correct"
        case volume
        case chapterNum = "chapter_num"
        case chapterName = "chapter_name"
        case topic
        case difficulty
        case confidence
    }
}

private struct AnthropicAPIResponse: Codable, Sendable {
    let content: [ContentBlock]

    struct ContentBlock: Codable, Sendable {
        let type: String
        let text: String?
    }
}

// MARK: - Service
// 使用 struct 而非 actor，避免 Swift 6 的 actor-isolation 與 @MainActor UIKit 類型的衝突。
// 所有方法均為 async，執行緒安全由 URLSession 保證。

struct AnthropicService: Sendable {
    static let shared = AnthropicService()
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// imageDatas：由呼叫端（@MainActor）壓縮後傳入，支援多張（多頁考卷）
    func analyzeExam(imageDatas: [Data], apiKey: String) async throws -> ExamAnalysisResponse {
        let prompt = buildPrompt()

        var contentBlocks: [[String: Any]] = imageDatas.map { data in
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": data.base64EncodedString()
                ]
            ]
        }
        contentBlocks.append(["type": "text", "text": prompt])

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 8192,
            "messages": [[
                "role": "user",
                "content": contentBlocks
            ]]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ServiceError.apiError(httpResponse.statusCode, errorText)
        }

        let apiResponse = try JSONDecoder().decode(AnthropicAPIResponse.self, from: data)
        guard let content = apiResponse.content.first?.text else {
            throw ServiceError.emptyResponse
        }

        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw ServiceError.parseError("回應內容無法轉換")
        }

        do {
            return try JSONDecoder().decode(ExamAnalysisResponse.self, from: jsonData)
        } catch {
            if let range = cleaned.range(of: #"\{.*\}"#, options: [.regularExpression, .caseInsensitive]),
               let fallbackData = String(cleaned[range]).data(using: .utf8),
               let result = try? JSONDecoder().decode(ExamAnalysisResponse.self, from: fallbackData) {
                return result
            }
            throw ServiceError.parseError(error.localizedDescription)
        }
    }

    private func buildPrompt() -> String {
        // CurriculumData.jsonString 是 static let，不受 actor-isolation 影響
        let curriculumJson = CurriculumData.jsonString
        return """
        你是台灣國中會考題庫建立專家。請仔細分析這張考卷圖片，將每一道題目完整抽取出來，作為題庫資料。

        ## 台灣108課綱國中課程章節參考：
        \(curriculumJson)

        ## 任務說明：
        請對圖片中**每一道可見的題目**進行完整分析，包括：

        ### 1. 科目識別
        從以下選項判斷：國文、英語、數學、社會-地理、社會-歷史、社會-公民、自然-生物、自然-理化、自然-地科

        ### 2. 完整題目內容提取
        - **題目文字**：逐字抄錄完整題目（含題幹、表格文字、圖表說明）
        - **選項**：如為選擇題，完整抄錄 A/B/C/D 四個選項
        - **題型**：選擇題 / 填充題 / 問答題 / 計算題

        ### 3. 答案識別
        - **正確答案**：如試卷上有標出正確答案則填入（如 "A"、"14"、"光合作用"）
        - **學生答案**：如有學生填寫/圈選的答案則填入
        - **批改結果**：觀察 ✓勾、✗叉、紅筆批改等標記判斷答對/答錯

        ### 4. 課綱對應
        根據題目內容，對應到上方課綱的：冊次（七上/七下/八上/八下/九上/九下）、章節編號、章節名稱、具體知識點

        ### 5. 難度估計
        根據題目複雜度判斷：easy（基礎）/ medium（一般）/ hard（進階）

        ## 輸出格式（純JSON，禁止加任何說明文字）：
        {
          "subject": "科目名稱",
          "questions": [
            {
              "number": 題號整數,
              "question_text": "完整題目文字（含題幹）",
              "question_type": "選擇題",
              "options": {"A": "選項A", "B": "選項B", "C": "選項C", "D": "選項D"},
              "correct_answer": "A",
              "student_answer": "B",
              "is_correct": false,
              "volume": "八上",
              "chapter_num": 3,
              "chapter_name": "化學反應與方程式",
              "topic": "化學反應式的平衡",
              "difficulty": "medium",
              "confidence": "high"
            }
          ],
          "notes": "整體備註"
        }

        重要規則：
        1. 每道題目的 question_text 必須完整，不可截斷
        2. 非選擇題的 options 填 null
        3. 無法判斷的欄位填 null，不要猜測
        4. 如題目包含圖表/圖形，在 question_text 中加上 "[含圖表]" 標記
        5. 只輸出JSON，絕對不要有其他文字
        """
    }

    enum ServiceError: LocalizedError, Sendable {
        case imageEncodingFailed
        case invalidResponse
        case apiError(Int, String)
        case emptyResponse
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .imageEncodingFailed: return "圖片編碼失敗"
            case .invalidResponse: return "無效的伺服器回應"
            case .apiError(let code, let msg): return "API 錯誤 (\(code))：\(msg)"
            case .emptyResponse: return "AI 回傳空白內容"
            case .parseError(let msg): return "解析錯誤：\(msg)"
            }
        }
    }
}
