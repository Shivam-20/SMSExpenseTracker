import Foundation

// MARK: - Expense Category

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case food          = "Food & Dining"
    case shopping      = "Shopping"
    case transport     = "Transport"
    case utilities     = "Utilities"
    case entertainment = "Entertainment"
    case healthcare    = "Healthcare"
    case finance       = "Finance & Banking"
    case other         = "Other"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .food:          return "🍔"
        case .shopping:      return "🛍️"
        case .transport:     return "🚗"
        case .utilities:     return "💡"
        case .entertainment: return "🎬"
        case .healthcare:    return "🏥"
        case .finance:       return "🏦"
        case .other:         return "📦"
        }
    }
}

// MARK: - Transaction Type

enum TransactionType: String, Codable {
    case debit   = "Debit"
    case credit  = "Credit"
    case unknown = "Unknown"
}

// MARK: - Expense Model

struct Expense: Identifiable, Codable {
    var id          = UUID()
    var amount      : Double
    var currency    : String
    var merchant    : String
    var date        : Date
    var category    : ExpenseCategory
    var type        : TransactionType
    var rawMessage  : String
    var bank        : String

    var formattedAmount: String {
        let symbol: String
        switch currency {
        case "USD": symbol = "$"
        case "EUR": symbol = "€"
        case "GBP": symbol = "£"
        default:    symbol = "₹"
        }
        return "\(symbol)\(String(format: "%.2f", amount))"
    }
}
