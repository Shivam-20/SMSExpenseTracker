import SwiftUI

struct ExpenseDetailView: View {
    @EnvironmentObject var store: ExpenseStore
    @Environment(\.dismiss) var dismiss
    @State var expense: Expense
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            List {
                Section("Transaction") {
                    detailRow(label: "Amount",   value: expense.formattedAmount)
                    detailRow(label: "Type",     value: expense.type.rawValue)
                    detailRow(label: "Merchant", value: expense.merchant)
                    detailRow(label: "Date",     value: expense.date.formatted(date: .long, time: .omitted))
                    detailRow(label: "Bank",     value: expense.bank)
                }
                Section("Category") {
                    HStack {
                        Text("Category")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(expense.category.emoji) \(expense.category.rawValue)")
                    }
                }
                Section("Raw SMS") {
                    Text(expense.rawMessage.isEmpty ? "—" : expense.rawMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                Section {
                    Button(role: .destructive) {
                        store.delete(expense)
                        dismiss()
                    } label: {
                        Label("Delete Expense", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Expense Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") { isEditing = true }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditExpenseView(expense: $expense) { updated in
                    store.update(updated)
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Edit Expense View

struct EditExpenseView: View {
    @Binding var expense: Expense
    var onSave: (Expense) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var amount   : String
    @State private var merchant : String
    @State private var date     : Date
    @State private var category : ExpenseCategory
    @State private var type     : TransactionType
    @State private var currency : String
    @State private var bank     : String

    init(expense: Binding<Expense>, onSave: @escaping (Expense) -> Void) {
        self._expense  = expense
        self.onSave    = onSave
        _amount   = State(initialValue: String(format: "%.2f", expense.wrappedValue.amount))
        _merchant = State(initialValue: expense.wrappedValue.merchant)
        _date     = State(initialValue: expense.wrappedValue.date)
        _category = State(initialValue: expense.wrappedValue.category)
        _type     = State(initialValue: expense.wrappedValue.type)
        _currency = State(initialValue: expense.wrappedValue.currency)
        _bank     = State(initialValue: expense.wrappedValue.bank)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Amount") {
                    HStack {
                        Picker("Currency", selection: $currency) {
                            ForEach(["INR","USD","EUR","GBP"], id: \.self) { Text($0) }
                        }.pickerStyle(.segmented)
                        TextField("0.00", text: $amount).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Details") {
                    TextField("Merchant", text: $merchant)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { c in
                            Text("\(c.emoji) \(c.rawValue)").tag(c)
                        }
                    }
                    Picker("Type", selection: $type) {
                        Text("Debit").tag(TransactionType.debit)
                        Text("Credit").tag(TransactionType.credit)
                    }.pickerStyle(.segmented)
                    TextField("Bank", text: $bank)
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commitEdit() }
                        .disabled(Double(amount) == nil)
                }
            }
        }
    }

    private func commitEdit() {
        guard let value = Double(amount) else { return }
        expense.amount   = value
        expense.currency = currency
        expense.merchant = merchant
        expense.date     = date
        expense.category = category
        expense.type     = type
        expense.bank     = bank
        onSave(expense)
        dismiss()
    }
}
