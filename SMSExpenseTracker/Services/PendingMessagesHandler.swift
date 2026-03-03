import Foundation
import Combine

// MARK: - Pending Messages Handler
// Reads messages saved by the Share Extension from the shared App Group,
// then parses and offers them as expenses in the main app.

final class PendingMessagesHandler: ObservableObject {

    static let shared = PendingMessagesHandler()

    @Published var pendingExpenses: [Expense] = []
    @Published var hasPending = false

    private let appGroupID  = ExpenseStore.appGroupID
    private let pendingKey  = "pendingSharedMessages"

    private init() {}

    func checkForPendingMessages() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let messages = defaults.stringArray(forKey: pendingKey) ?? []
        guard !messages.isEmpty else { return }

        let expenses = messages.flatMap { SMSParser.parseMultiple(from: $0) }

        DispatchQueue.main.async { [weak self] in
            self?.pendingExpenses = expenses
            self?.hasPending      = !expenses.isEmpty
        }

        // Clear the queue
        defaults.removeObject(forKey: pendingKey)
        defaults.synchronize()
    }

    func clearPending() {
        pendingExpenses = []
        hasPending      = false
    }
}
