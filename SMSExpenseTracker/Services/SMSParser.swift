import Foundation

// MARK: - SMS Parser
// Parses expense/transaction data from raw SMS text using regex patterns.
// Supports INR, USD, EUR, GBP. Handles debit/credit bank messages from
// common formats used by Indian & international banks.

struct SMSParser {

    // MARK: Public API

    static func parse(_ text: String) -> Expense? {
        guard isExpenseMessage(text) else { return nil }
        guard let amount = extractAmount(from: text) else { return nil }

        let currency = extractCurrency(from: text)
        let merchant = extractMerchant(from: text)
        let date     = extractDate(from: text) ?? Date()
        let type     = extractTransactionType(from: text)
        let bank     = extractBank(from: text)
        let category = categorize(merchant: merchant, message: text)

        return Expense(
            amount:     amount,
            currency:   currency,
            merchant:   merchant,
            date:       date,
            category:   category,
            type:       type,
            rawMessage: text,
            bank:       bank
        )
    }

    static func parseMultiple(from text: String) -> [Expense] {
        // Split by common delimiters when user pastes multiple messages
        let separators = ["\n\n", "---", "===", "***"]
        var chunks = [text]
        for sep in separators {
            if text.contains(sep) {
                chunks = text.components(separatedBy: sep)
                break
            }
        }
        return chunks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { parse($0) }
    }

    // MARK: Detection

    static func isExpenseMessage(_ text: String) -> Bool {
        let keywords = [
            "debited", "credited", "spent", "paid", "payment",
            "purchase", "transaction", "withdrawn", "transferred",
            "debit", "credit", "charged", "deducted", "received",
            "INR", "Rs.", "₹", "refund", "cashback"
        ]
        let lower = text.lowercased()
        return keywords.contains { lower.contains($0.lowercased()) }
    }

    // MARK: Amount Extraction

    static func extractAmount(from text: String) -> Double? {
        // Pattern priority: currency symbol/code adjacent to number
        let patterns: [String] = [
            // ₹1,234.56 or Rs.1234 or INR 1,234
            "(?:₹|Rs\\.?|INR)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)",
            // $1,234.56 or USD 1234
            "(?:\\$|USD)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)",
            // €1,234 or EUR 1234
            "(?:€|EUR)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)",
            // £1,234 or GBP 1234
            "(?:£|GBP)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)",
            // Number followed by currency
            "([0-9,]+(?:\\.[0-9]{1,2})?)\\s*(?:₹|Rs\\.?|INR|USD|EUR|GBP)",
            // "amount of 1234" / "amt: 1234"
            "(?:amount|amt)[\\s:of]+(?:Rs\\.?|₹|\\$)?\\s*([0-9,]+(?:\\.[0-9]{1,2})?)"
        ]

        for pattern in patterns {
            if let match = firstCapture(pattern: pattern, in: text, options: .caseInsensitive) {
                let clean = match.replacingOccurrences(of: ",", with: "")
                if let value = Double(clean), value > 0 { return value }
            }
        }
        return nil
    }

    // MARK: Currency Extraction

    static func extractCurrency(from text: String) -> String {
        if text.contains("₹") || containsWord("INR", in: text) || text.contains("Rs.") || text.contains("Rs ") { return "INR" }
        if text.contains("$")  || containsWord("USD", in: text) { return "USD" }
        if text.contains("€")  || containsWord("EUR", in: text) { return "EUR" }
        if text.contains("£")  || containsWord("GBP", in: text) { return "GBP" }
        return "INR"
    }

    // MARK: Merchant Extraction

    static func extractMerchant(from text: String) -> String {
        let patterns = [
            // "at MERCHANT NAME"
            "\\bat\\s+([A-Z][A-Za-z0-9\\s&\\.\\-']{2,35})(?=\\s*(?:on|via|for|\\.|,|$))",
            // "to MERCHANT" / "towards MERCHANT"
            "\\b(?:to|towards)\\s+([A-Z][A-Za-z0-9\\s&\\.\\-']{2,35})(?=\\s*(?:on|via|for|\\.|,|$))",
            // "merchant: MERCHANT"
            "merchant[:\\s]+([A-Za-z0-9\\s&\\.\\-']{2,35})(?=\\s*(?:\\.|,|$))",
            // UPI: "VPA abc@bank"
            "(?:UPI|VPA)[:\\s]+([A-Za-z0-9\\.@_\\-]{4,40})"
        ]

        for pattern in patterns {
            if let match = firstCapture(pattern: pattern, in: text) {
                let cleaned = match.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && cleaned != "your" { return cleaned }
            }
        }
        return "Unknown"
    }

    // MARK: Date Extraction

    static func extractDate(from text: String) -> Date? {
        let formatPairs: [(pattern: String, format: String)] = [
            ("(\\d{2}/\\d{2}/\\d{4})",                               "dd/MM/yyyy"),
            ("(\\d{2}-\\d{2}-\\d{4})",                               "dd-MM-yyyy"),
            ("(\\d{4}-\\d{2}-\\d{2})",                               "yyyy-MM-dd"),
            ("(\\d{2}\\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+\\d{4})", "dd MMM yyyy"),
            ("(\\d{1,2}/\\d{1,2}/\\d{2})",                           "d/M/yy"),
            ("(\\d{2}-\\d{2}-\\d{2})",                               "dd-MM-yy"),
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for pair in formatPairs {
            if let raw = firstCapture(pattern: pair.pattern, in: text, options: .caseInsensitive) {
                formatter.dateFormat = pair.format
                if let date = formatter.date(from: raw) { return date }
            }
        }
        return nil
    }

    // MARK: Transaction Type

    static func extractTransactionType(from text: String) -> TransactionType {
        let lower = text.lowercased()
        let debitWords  = ["debited", "debit", "spent", "paid", "withdrawn", "deducted", "charged", "purchase"]
        let creditWords = ["credited", "credit", "received", "refund", "cashback", "reversal"]
        if debitWords.contains(where: { lower.contains($0) })  { return .debit }
        if creditWords.contains(where: { lower.contains($0) }) { return .credit }
        return .unknown
    }

    // MARK: Bank Extraction

    static func extractBank(from text: String) -> String {
        let banks: [(keyword: String, name: String)] = [
            ("HDFC",  "HDFC Bank"),
            ("ICICI", "ICICI Bank"),
            ("SBI",   "State Bank of India"),
            ("AXIS",  "Axis Bank"),
            ("KOTAK", "Kotak Bank"),
            ("BOI",   "Bank of India"),
            ("PNB",   "Punjab National Bank"),
            ("CANARA","Canara Bank"),
            ("YES",   "Yes Bank"),
            ("INDUSIND","IndusInd Bank"),
            ("CHASE", "Chase Bank"),
            ("CITI",  "Citibank"),
            ("WELLS FARGO","Wells Fargo"),
            ("BARCLAYS","Barclays"),
            ("PAYTM", "Paytm"),
            ("GPAY",  "Google Pay"),
            ("PHONEPE","PhonePe"),
            ("AMAZONPAY","Amazon Pay"),
        ]
        let upper = text.uppercased()
        for bank in banks {
            if upper.contains(bank.keyword) { return bank.name }
        }
        return "Unknown"
    }

    // MARK: Category

    static func categorize(merchant: String, message: String) -> ExpenseCategory {
        let combined = (merchant + " " + message).lowercased()

        let rules: [(keywords: [String], category: ExpenseCategory)] = [
            (["zomato","swiggy","foodpanda","dunzo","blinkit","instamart","restaurant","cafe","coffee","pizza","burger","kfc","mcdonald","domino","subway","dining","food","biryani","bakery"], .food),
            (["amazon","flipkart","myntra","ajio","meesho","nykaa","snapdeal","ebay","shopify","retail","store","mart","mall","bazaar","shop","bigbasket","grofer","jiomart","grocery"], .shopping),
            (["uber","ola","lyft","rapido","auto","taxi","metro","bus","train","irctc","petrol","fuel","diesel","parking","toll","fastag","indigo","spicejet","air india","flight"], .transport),
            (["jio","airtel","vodafone","vi ","bsnl","electricity","water","gas","internet","broadband","bill","recharge","utility","dth","tata sky"], .utilities),
            (["netflix","hotstar","prime video","spotify","wynk","gaana","youtube","movie","cinema","pvr","inox","theatre","bookmyshow","gaming","game","steam"], .entertainment),
            (["hospital","pharmacy","medplus","apollo","1mg","netmeds","doctor","clinic","health","dental","medicine","medifast","ayurvedic","lab test"], .healthcare),
            (["insurance","loan","emi","neft","rtgs","imps","mutual fund","sip","stock","zerodha","groww","nse","bse","tax","gst","fd ","ppf "], .finance),
        ]

        for rule in rules {
            if rule.keywords.contains(where: { combined.contains($0) }) { return rule.category }
        }
        return .other
    }

    // MARK: Helpers

    private static func firstCapture(pattern: String, in text: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        let pattern = "\\b\(word)\\b"
        return (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))
            .flatMap { $0.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) } != nil
    }
}
