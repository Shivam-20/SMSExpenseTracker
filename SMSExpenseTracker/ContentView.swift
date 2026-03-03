import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store   : ExpenseStore
    @EnvironmentObject var pending : PendingMessagesHandler
    @State private var tab            : Tab  = .expenses
    @State private var showPendingSheet       = false

    enum Tab { case expenses, add, export }

    var body: some View {
        TabView(selection: $tab) {
            ExpenseListView()
                .tabItem { Label("Expenses", systemImage: "list.bullet.rectangle") }
                .tag(Tab.expenses)

            AddExpenseView(onDone: { tab = .expenses })
                .tabItem { Label("Scan SMS", systemImage: "message.badge.filled.fill") }
                .tag(Tab.add)

            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
                .tag(Tab.export)
        }
        .accentColor(.indigo)
        // Show banner when Share Extension has queued messages
        .sheet(isPresented: $showPendingSheet) {
            PendingMessagesSheet(expenses: pending.pendingExpenses) { selected in
                store.addAll(selected)
                pending.clearPending()
            }
        }
        .onChange(of: pending.hasPending) { hasPending in
            if hasPending { showPendingSheet = true }
        }
    }
}

// MARK: - Pending Messages Sheet
// Shown when the Share Extension has delivered new messages.

struct PendingMessagesSheet: View {
    let expenses: [Expense]
    let onAdd   : ([Expense]) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedIDs = Set<UUID>()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if expenses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray").font(.largeTitle).foregroundColor(.secondary)
                        Text("No expense messages found in the shared text.")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        Section("\(expenses.count) expense(s) detected") {
                            ForEach(expenses) { exp in
                                Button { toggle(exp.id) } label: {
                                    HStack {
                                        Image(systemName: selectedIDs.contains(exp.id)
                                              ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedIDs.contains(exp.id) ? .indigo : .secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(exp.category.emoji) \(exp.merchant)")
                                                .font(.subheadline).bold()
                                            Text("\(exp.formattedAmount) · \(exp.date, style: .date)")
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Shared Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedIDs.count)") {
                        onAdd(expenses.filter { selectedIDs.contains($0.id) })
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Select All") {
                        selectedIDs = Set(expenses.map { $0.id })
                    }
                }
            }
            .onAppear {
                selectedIDs = Set(expenses.map { $0.id })
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }
}
