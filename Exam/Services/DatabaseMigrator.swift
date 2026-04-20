import Foundation
import SwiftData
import SQLite3

/// 將 SQLite (exam_data.db) 資料遷移至 SwiftData；當 DB 檔案異動時自動重新匯入歷屆題庫
enum DatabaseMigrator {
    private static let migrationVersionKey = "sqlite_migration_version"

    // MARK: - Public

    /// 在 App 啟動時呼叫；DB 未變動且資料已存在則跳過，否則匯入歷屆題庫（year > 0）。
    /// 若 CloudKit 已從其他裝置同步歷屆資料，也會跳過匯入以避免重複。
    @MainActor
    static func migrateIfNeeded(context: ModelContext, dbURL: URL) {
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            print("[Migrator] 找不到 exam_data.db，跳過遷移")
            return
        }

        let version = fileFingerprint(dbURL)
        let stored  = UserDefaults.standard.string(forKey: migrationVersionKey) ?? ""

        // 必須先確認資料是否存在，版本相符但題庫為空仍需匯入
        // （例如：之前在 CloudKit container 匯入後版本號已存，現在換成本地 container 資料是空的）
        let existingCount = (try? context.fetchCount(
            FetchDescriptor<QuestionBankItem>(predicate: #Predicate { $0.year > 0 })
        )) ?? 0

        // 跳過條件：版本相符 AND 已有資料
        guard version != stored || existingCount == 0 else {
            print("[Migrator] 版本相符且已有 \(existingCount) 題，跳過匯入")
            return
        }

        // 已有資料（可能來自 iCloud）但版本不同：僅更新版本號，不重複匯入
        if existingCount > 0 {
            print("[Migrator] 偵測到 \(existingCount) 題歷屆資料（可能來自 iCloud），跳過本地匯入")
            UserDefaults.standard.set(version, forKey: migrationVersionKey)
            return
        }

        if !stored.isEmpty {
            print("[Migrator] 題庫版本更新，清除舊歷屆資料...")
            try? context.delete(model: QuestionBankItem.self, where: #Predicate { $0.year > 0 })
            try? context.save()
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            print("[Migrator] 無法開啟 SQLite：\(String(cString: sqlite3_errmsg(db)))")
            return
        }
        defer { sqlite3_close(db) }

        let examIdMap = migrateExams(db: db, context: context)
        migrateQuestionBank(db: db, context: context, examIdMap: examIdMap)
        migratePracticeSessions(db: db, context: context)

        try? context.save()
        UserDefaults.standard.set(version, forKey: migrationVersionKey)
        let importedCount = (try? context.fetchCount(
            FetchDescriptor<QuestionBankItem>(predicate: #Predicate { $0.year > 0 })
        )) ?? 0
        print("[Migrator] 遷移完成，共 \(importedCount) 題（version=\(version)）")
    }

    private static func fileFingerprint(_ url: URL) -> String {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return "\(size)"
    }

    // MARK: - Private helpers

    /// 回傳 SQLite exam.id → 新 SwiftData Exam.id 的對照表
    @MainActor
    private static func migrateExams(db: OpaquePointer?, context: ModelContext) -> [Int64: UUID] {
        var map: [Int64: UUID] = [:]
        let sql = "SELECT id, filename, subject, created_at, raw_json FROM exams"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return map }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let sqliteId   = sqlite3_column_int64(stmt, 0)
            let filename   = columnText(stmt, 1)
            let subject    = columnText(stmt, 2)
            let createdStr = columnText(stmt, 3)
            let rawJson    = columnText(stmt, 4)

            let exam = Exam(
                subject: subject,
                imageName: filename,
                rawJson: rawJson
            )
            exam.createdAt = parseDate(createdStr) ?? Date()

            // 還原 questions（從 raw_json）
            if let data = rawJson.data(using: .utf8),
               let response = try? JSONDecoder().decode(ExamAnalysisResponse.self, from: data) {
                for q in response.questions {
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
                    exam.questions?.append(eq)
                }
            }

            context.insert(exam)
            map[sqliteId] = exam.id
        }
        return map
    }

    @MainActor
    private static func migrateQuestionBank(db: OpaquePointer?, context: ModelContext, examIdMap: [Int64: UUID]) {
        // 檢查是否有新欄位（歷屆題庫版 schema）
        let hasNewColumns = columnExists(db: db, table: "question_bank", column: "year")

        let sql = hasNewColumns ? """
            SELECT source_exam_id, subject, volume, chapter_num, chapter_name, topic,
                   question_num, question_text, question_type,
                   option_a, option_b, option_c, option_d,
                   correct_answer, difficulty, first_attempt_correct, created_at,
                   year, pass_rate, explanation
            FROM question_bank
        """ : """
            SELECT source_exam_id, subject, volume, chapter_num, chapter_name, topic,
                   question_num, question_text, question_type,
                   option_a, option_b, option_c, option_d,
                   correct_answer, difficulty, first_attempt_correct, created_at
            FROM question_bank
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let sourceExamSQLiteId = sqlite3_column_int64(stmt, 0)
            let sourceExamId = examIdMap[sourceExamSQLiteId] ?? UUID()

            let firstAttemptRaw = sqlite3_column_type(stmt, 15) == SQLITE_NULL
                ? nil : sqlite3_column_int(stmt, 15) == 1

            let year        = hasNewColumns ? Int(sqlite3_column_int(stmt, 17)) : 0
            let passRateRaw = hasNewColumns && sqlite3_column_type(stmt, 18) != SQLITE_NULL
                ? sqlite3_column_double(stmt, 18) : -1.0
            let explanation = hasNewColumns ? columnText(stmt, 19) : ""

            let item = QuestionBankItem(
                sourceExamId: sourceExamId,
                year:          year,
                subject:       columnText(stmt, 1),
                volume:        columnText(stmt, 2),
                chapterNum:    Int(sqlite3_column_int(stmt, 3)),
                chapterName:   columnText(stmt, 4),
                topic:         columnText(stmt, 5),
                questionNum:   Int(sqlite3_column_int(stmt, 6)),
                questionText:  columnText(stmt, 7),
                questionType:  columnText(stmt, 8),
                optionA:       optionalText(stmt, 9),
                optionB:       optionalText(stmt, 10),
                optionC:       optionalText(stmt, 11),
                optionD:       optionalText(stmt, 12),
                correctAnswer: optionalText(stmt, 13),
                passRate:      passRateRaw,
                difficulty:    columnText(stmt, 14),
                explanation:   explanation,
                firstAttemptCorrect: firstAttemptRaw
            )
            item.createdAt = parseDate(columnText(stmt, 16)) ?? Date()
            context.insert(item)
        }
    }

    private static func columnExists(db: OpaquePointer?, table: String, column: String) -> Bool {
        let sql = "PRAGMA table_info(\(table))"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if columnText(stmt, 1) == column { return true }
        }
        return false
    }

    @MainActor
    private static func migratePracticeSessions(db: OpaquePointer?, context: ModelContext) {
        // 讀取 sessions
        var sessions: [Int64: PracticeSession] = [:]
        let sessionSQL = "SELECT id, subject, total, correct, created_at, finished_at FROM practice_sessions"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sessionSQL, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let sqliteId    = sqlite3_column_int64(stmt, 0)
                let subject     = columnText(stmt, 1)
                let total       = Int(sqlite3_column_int(stmt, 2))
                let correct     = Int(sqlite3_column_int(stmt, 3))
                let createdStr  = columnText(stmt, 4)
                let finishedStr = optionalText(stmt, 5)

                let session = PracticeSession(subject: subject, questionCount: total)
                session.correctCount = correct
                session.createdAt    = parseDate(createdStr) ?? Date()
                session.finishedAt   = finishedStr.flatMap { parseDate($0) }
                context.insert(session)
                sessions[sqliteId] = session
            }
        }
        sqlite3_finalize(stmt)

        // 讀取 attempts（注意：舊 question_id 為 SQLite integer，這裡只記錄 isCorrect）
        let attemptSQL = "SELECT session_id, question_id, is_correct, attempted_at FROM practice_attempts"
        var stmt2: OpaquePointer?
        if sqlite3_prepare_v2(db, attemptSQL, -1, &stmt2, nil) == SQLITE_OK {
            while sqlite3_step(stmt2) == SQLITE_ROW {
                let sessionId  = sqlite3_column_int64(stmt2, 0)
                let isCorrect  = sqlite3_column_int(stmt2, 2) == 1
                let attempted  = columnText(stmt2, 3)
                guard let session = sessions[sessionId] else { continue }

                // 舊系統用 SQLite integer 作為 question_id，新系統用 UUID
                // 嘗試在已遷移的題庫中依序對應（保留嘗試記錄但不強制對應）
                let attempt = PracticeAttempt(questionId: UUID(), isCorrect: isCorrect)
                attempt.attemptedAt = parseDate(attempted) ?? Date()
                attempt.session = session
                session.attempts?.append(attempt)
                context.insert(attempt)
            }
        }
        sqlite3_finalize(stmt2)
    }

    // MARK: - SQLite column helpers

    private static func columnText(_ stmt: OpaquePointer?, _ col: Int32) -> String {
        guard let cStr = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: cStr)
    }

    private static func optionalText(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL,
              let cStr = sqlite3_column_text(stmt, col) else { return nil }
        let s = String(cString: cStr)
        return s.isEmpty ? nil : s
    }

    private static func parseDate(_ str: String) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            fmt.dateFormat = format
            if let d = fmt.date(from: str) { return d }
        }
        return nil
    }
}
