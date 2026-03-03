import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject var store: ExpenseStore
    var onDone: () -> Void

    @State private var smsText          = ""
    @State private var parsedExpenses   : [Expense] = []
    @State private var isParsing        = false
    @State private var showResults      = false
    @State private var selectedIDs      = Set<UUID>()
    @State private var showManualEntry  = false
    @State private var showPasteHint    = true

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    infoCard
                    pasteSection
                    if isParsing {
                        ProgressView("Analysing messages…")
                            .padding()
                    }
                    if showResults {
                        resultsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Scan SMS")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manual Entry") { showManualEntry = true }
                        .font(.subheadline)
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualExpenseEntryView { expense in
                    store.add(expense)
                    onDone()
                }
            }
        }
    }

    // MARK: Sub-views

    private var infoCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.indigo)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("How to scan SMS")
                    .font(.subheadline).bold()
                Text("1. Open the **Messages** app\n2. Long-press a bank SMS → **More…**\n3. Select messages → **Share** → **SMS Expense Tracker**\n\nOr paste SMS text directly below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.indigo.opacity(0.08))
        .cornerRadius(12)
    }

    private var pasteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Paste SMS Text")
                    .font(.headline)
                Spacer()
                if !smsText.isEmpty {
                    Button("Clear") { smsText = ""; parsedExpenses = []; showResults = false }
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    .frame(minHeight: 160)

                if smsText.isEmpty {
                    Text("Paste one or more bank/transaction SMS messages here...\n\nExample:\nYour A/C XX1234 is debited by ₹2,500.00 on 01-Jan-2025 at ZOMATO")
                        .foregroundColor(.secondary)
                        .padding(14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $smsText)
                    .frame(minHeight: 160)
                    .padding(10)
                    .opacity(smsText.isEmpty ? 0.25 : 1)
            }

            HStack(spacing: 12) {
                Button {
                    if let clip = UIPasteboard.general.string {
                        smsText = clip
                    }
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    analyseText()
                } label: {
                    Label("Analyse", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(smsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Text("Found \(parsedExpenses.count) expense(s)")
                    .font(.headline)
                Spacer()
                Button("Select All") { selectedIDs = Set(parsedExpenses.map { $0.id }) }
                    .font(.subheadline)
            }

            if parsedExpenses.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("No expense messages detected. Make sure the text contains amount and transaction keywords.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.08))
                .cornerRadius(10)
            } else {
                ForEach(parsedExpenses) { expense in
                    ParsedExpenseCard(
                        expense: expense,
                        isSelected: selectedIDs.contains(expense.id),
                        onToggle: { toggleSelection(expense.id) }
                    )
                }

                if !selectedIDs.isEmpty {
                    Button {
                        let toAdd = parsedExpenses.filter { selectedIDs.contains($0.id) }
                        store.addAll(toAdd)
                        smsText       = ""
                        parsedExpenses = []
                        showResults   = false
                        selectedIDs   = []
                        onDone()
                    } label: {
                        Label("Add \(selectedIDs.count) expense(s)", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
        }
    }

    // MARK: Actions

    private func analyseText() {
        isParsing = true
        showResults = false
        DispatchQueue.global(qos: .userInitiated).async {
            let results = SMSParser.parseMultiple(from: smsText)
            DispatchQueue.main.async {
                parsedExpenses = results
                selectedIDs    = Set(results.map { $0.id })
                isParsing      = false
                showResults    = true
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }
}

// MARK: - Parsed Expense Card

struct ParsedExpenseCard: View {
    let expense    : Expense
    let isSelected : Bool
    let onToggle   : () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .indigo : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(expense.category.emoji + " " + expense.merchant)
                            .font(.subheadline).bold()
                        Spacer()
                        Text(expense.formattedAmount)
                            .font(.subheadline).bold()
                            .foregroundColor(expense.type == .credit ? .green : .red)
                    }
                    HStack {
                        Text(expense.category.rawValue)
                            .font(.caption).foregroundColor(.secondary)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(expense.date, style: .date)
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(expense.type.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(expense.type == .credit ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                            .foregroundColor(expense.type == .credit ? .green : .red)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.indigo.opacity(0.06) : Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.indigo.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Manual Expense Entry

struct ManualExpenseEntryView: View {
    var onSave: (Expense) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var amount    = ""
    @State private var merchant  = ""
    @State private var date      = Date()
    @State private var category  = ExpenseCategory.other
    @State private var type      = TransactionType.debit
    @State private var currency  = "INR"
    @State private var bank      = ""
    @State private var rawMsg    = ""

    private let currencies = ["INR","USD","EUR","GBP"]

    var body: some View {
        NavigationView {
            Form {
                Section("Amount") {
                    HStack {
                        Picker("Currency", selection: $currency) {
                            ForEach(currencies, id: \.self) { Text($0) }
                        }.pickerStyle(.segmented)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Details") {
                    TextField("Merchant / Store", text: $merchant)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Text("\(cat.emoji) \(cat.rawValue)").tag(cat)
                        }
                    }
                    Picker("Type", selection: $type) {
                        Text("Debit").tag(TransactionType.debit)
                        Text("Credit").tag(TransactionType.credit)
                    }.pickerStyle(.segmented)
                }
                Section("Optional") {
                    TextField("Bank", text: $bank)
                    TextField("Original SMS (optional)", text: $rawMsg, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExpense() }
                        .disabled(amount.isEmpty || Double(amount) == nil)
                }
            }
        }
    }

    private func saveExpense() {
        guard let value = Double(amount) else { return }
        let expense = Expense(
            amount:     value,
            currency:   currency,
            merchant:   merchant.isEmpty ? "Unknown" : merchant,
            date:       date,
            category:   category,
            type:       type,
            rawMessage: rawMsg,
            bank:       bank.isEmpty ? "Unknown" : bank
        )
        onSave(expense)
        dismiss()
    }
}
