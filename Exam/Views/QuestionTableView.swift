import SwiftUI

// MARK: - Table View

/// 將 TableData 渲染成帶邊框的表格
struct QuestionTableView: View {
    let table: TableData

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                // 標題列
                if !table.headers.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(table.headers.indices, id: \.self) { i in
                            Text(table.headers[i])
                                .font(.caption.bold())
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(minWidth: 64, maxWidth: .infinity)
                                .background(Color.secondary.opacity(0.12))
                                .overlay(alignment: .trailing) {
                                    if i < table.headers.count - 1 {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.25))
                                            .frame(width: 1)
                                    }
                                }
                        }
                    }
                    Divider().background(Color.secondary.opacity(0.4))
                }

                // 資料列
                ForEach(table.rows.indices, id: \.self) { rowIdx in
                    let row = table.rows[rowIdx]
                    HStack(spacing: 0) {
                        ForEach(row.indices, id: \.self) { colIdx in
                            Text(row[colIdx])
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(minWidth: 64, maxWidth: .infinity)
                                .background(rowIdx.isMultiple(of: 2)
                                            ? Color.clear
                                            : Color.secondary.opacity(0.04))
                                .overlay(alignment: .trailing) {
                                    if colIdx < row.count - 1 {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(width: 1)
                                    }
                                }
                        }
                    }
                    if rowIdx < table.rows.count - 1 {
                        Divider().background(Color.secondary.opacity(0.15))
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Decode Helper

extension QuestionBankItem {
    var decodedTable: TableData? {
        guard let json = tableJson,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TableData.self, from: data)
    }
}

extension ExamQuestion {
    var decodedTable: TableData? {
        guard let json = tableJson,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TableData.self, from: data)
    }
}
