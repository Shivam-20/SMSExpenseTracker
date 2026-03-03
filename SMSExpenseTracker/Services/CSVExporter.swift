import Foundation

// MARK: - CSV Exporter
// Generates a .csv file that opens directly in Excel, Numbers, or Google Sheets.

struct CSVExporter {

    // MARK: Generate CSV Data

    static func generateCSV(from expenses: [Expense]) -> Data {
        var rows: [String] = []

        // Header row
        rows.append([
            "Date", "Amount", "Currency", "Type",
            "Merchant", "Category", "Bank", "Raw SMS"
        ].map(csvEscape).joined(separator: ","))

        // Data rows
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"

        for expense in expenses {
            let row = [
                formatter.string(from: expense.date),
                String(format: "%.2f", expense.amount),
                expense.currency,
                expense.type.rawValue,
                expense.merchant,
                expense.category.rawValue,
                expense.bank,
                expense.rawMessage
            ].map(csvEscape).joined(separator: ",")
            rows.append(row)
        }

        // Summary section
        rows.append("")
        rows.append("SUMMARY,,,,,,,,")
        rows.append("Total Expenses (Debit),\(String(format: "%.2f", expenses.filter { $0.type == .debit }.reduce(0) { $0 + $1.amount })),,,,,,")
        rows.append("Total Credits,\(String(format: "%.2f", expenses.filter { $0.type == .credit }.reduce(0) { $0 + $1.amount })),,,,,,")
        rows.append("Total Transactions,\(expenses.count),,,,,,")

        // Category breakdown
        rows.append("")
        rows.append("CATEGORY BREAKDOWN,,,,,,,,")
        rows.append("Category,Total Amount,Transaction Count,,,,,")
        for category in ExpenseCategory.allCases {
            let categoryExpenses = expenses.filter { $0.category == category && $0.type == .debit }
            if !categoryExpenses.isEmpty {
                let total = categoryExpenses.reduce(0) { $0 + $1.amount }
                rows.append("\(csvEscape(category.rawValue)),\(String(format: "%.2f", total)),\(categoryExpenses.count),,,,,")
            }
        }

        let csv = rows.joined(separator: "\n")
        // BOM for Excel UTF-8 compatibility
        return Data([0xEF, 0xBB, 0xBF]) + (csv.data(using: .utf8) ?? Data())
    }

    // MARK: Save to temp file

    static func saveToTempFile(expenses: [Expense]) -> URL? {
        let data = generateCSV(from: expenses)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let filename = "expenses_\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("CSVExporter write error: \(error)")
            return nil
        }
    }

    // MARK: CSV Escaping

    private static func csvEscape(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\"", with: "\"\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        // Wrap in quotes if contains comma, quote, or newline
        if escaped.contains(",") || escaped.contains("\"") || value.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
