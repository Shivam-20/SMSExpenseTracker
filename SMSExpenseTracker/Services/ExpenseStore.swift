import Foundation
import Combine

// MARK: - Expense Store
// Persists expenses to disk (JSON in App Group container so the
// Share Extension can also write to the same store).

final class ExpenseStore: ObservableObject {

    static let shared = ExpenseStore()
    static let appGroupID = "group.com.example.SMSExpenseTracker"

    @Published var expenses: [Expense] = []

    private let fileName = "expenses.json"

    private var fileURL: URL {
        // Use App Group container so Share Extension can share data
        if let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            return containerURL.appendingPathComponent(fileName)
        }
        // Fallback to Documents
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    private init() {
        load()
    }

    // MARK: CRUD

    func add(_ expense: Expense) {
        expenses.insert(expense, at: 0)
        save()
    }

    func addAll(_ newExpenses: [Expense]) {
        expenses.insert(contentsOf: newExpenses, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        expenses.remove(atOffsets: offsets)
        save()
    }

    func delete(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        save()
    }

    func update(_ expense: Expense) {
        if let idx = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[idx] = expense
            save()
        }
    }

    func deleteAll() {
        expenses.removeAll()
        save()
    }

    // MARK: Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(expenses)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ExpenseStore save error: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([Expense].self, from: data)
        else { return }
        expenses = saved
    }

    // MARK: Stats

    var totalDebits: Double {
        expenses.filter { $0.type == .debit }.reduce(0) { $0 + $1.amount }
    }

    var totalCredits: Double {
        expenses.filter { $0.type == .credit }.reduce(0) { $0 + $1.amount }
    }

    func expenses(for category: ExpenseCategory) -> [Expense] {
        expenses.filter { $0.category == category }
    }

    func expenses(in dateRange: ClosedRange<Date>) -> [Expense] {
        expenses.filter { dateRange.contains($0.date) }
    }
}
