import SwiftUI

struct ExpenseListView: View {
    @EnvironmentObject var store: ExpenseStore
    @State private var searchText       = ""
    @State private var selectedCategory : ExpenseCategory? = nil
    @State private var selectedExpense  : Expense?         = nil
    @State private var showDeleteAlert  = false

    private var filtered: [Expense] {
        store.expenses
            .filter { selectedCategory == nil || $0.category == selectedCategory }
            .filter {
                searchText.isEmpty ||
                $0.merchant.localizedCaseInsensitiveContains(searchText) ||
                $0.rawMessage.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ── Summary Banner ─────────────────────────────────────
                summaryBanner

                // ── Category Filter ────────────────────────────────────
                categoryFilter

                // ── List ───────────────────────────────────────────────
                if filtered.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filtered) { expense in
                            Button { selectedExpense = expense } label: {
                                ExpenseRowView(expense: expense)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteExpenses)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("💸 Expenses")
            .searchable(text: $searchText, prompt: "Search merchant or SMS text")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !store.expenses.isEmpty {
                        Button(role: .destructive) { showDeleteAlert = true } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    }
                }
            }
            .alert("Delete All Expenses?", isPresented: $showDeleteAlert) {
                Button("Delete All", role: .destructive) { store.deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(item: $selectedExpense) { expense in
                ExpenseDetailView(expense: expense)
            }
        }
    }

    // MARK: Sub-views

    private var summaryBanner: some View {
        HStack(spacing: 0) {
            summaryCard(title: "Total Spent", amount: store.totalDebits, color: .red)
            Divider()
            summaryCard(title: "Total Received", amount: store.totalCredits, color: .green)
            Divider()
            VStack(spacing: 4) {
                Text("\(store.expenses.count)")
                    .font(.title2).bold()
                Text("Transactions")
                    .font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    private func summaryCard(title: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("₹\(String(format: "%.0f", amount))")
                .font(.title3).bold().foregroundColor(color)
            Text(title)
                .font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(title: "All", emoji: "📋", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ExpenseCategory.allCases) { cat in
                    filterChip(title: cat.rawValue, emoji: cat.emoji, isSelected: selectedCategory == cat) {
                        selectedCategory = (selectedCategory == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func filterChip(title: String, emoji: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(emoji) \(title)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.indigo : Color(.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.indigo.opacity(0.4), lineWidth: 1))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray.fill")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No Expenses Yet")
                .font(.title3).bold()
            Text("Tap \"Scan SMS\" to paste bank messages\nand extract expenses automatically.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Spacer()
        }
    }

    private func deleteExpenses(at offsets: IndexSet) {
        let toDelete = offsets.map { filtered[$0] }
        toDelete.forEach { store.delete($0) }
    }
}

// MARK: - Expense Row

struct ExpenseRowView: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 14) {
            // Category emoji circle
            Text(expense.category.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(categoryColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(expense.merchant)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(expense.formattedAmount)
                        .font(.headline)
                        .foregroundColor(expense.type == .credit ? .green : .primary)
                }
                HStack {
                    Text(expense.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(expense.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    typeBadge
                    if expense.bank != "Unknown" {
                        Text(expense.bank)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        switch expense.category {
        case .food:          return .orange
        case .shopping:      return .pink
        case .transport:     return .blue
        case .utilities:     return .yellow
        case .entertainment: return .purple
        case .healthcare:    return .red
        case .finance:       return .green
        case .other:         return .gray
        }
    }

    private var typeBadge: some View {
        Text(expense.type.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(expense.type == .credit ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
            .foregroundColor(expense.type == .credit ? .green : .red)
            .clipShape(Capsule())
    }
}
