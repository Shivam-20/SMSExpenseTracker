import SwiftUI

struct ExportView: View {
    @EnvironmentObject var store: ExpenseStore
    @State private var showShareSheet  = false
    @State private var exportURL       : URL?
    @State private var isGenerating    = false
    @State private var filterStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var filterEndDate   = Date()
    @State private var useDateFilter   = false
    @State private var selectedTypes   = Set<TransactionType>([.debit, .credit, .unknown])

    private var expensesToExport: [Expense] {
        store.expenses.filter { expense in
            let inDateRange = !useDateFilter || (expense.date >= filterStartDate && expense.date <= filterEndDate)
            let typeMatch   = selectedTypes.contains(expense.type)
            return inDateRange && typeMatch
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // ── Preview Stats ────────────────────────────────────
                Section("Export Preview") {
                    statsRow("Total transactions", value: "\(expensesToExport.count)")
                    statsRow("Debits",  value: "₹\(String(format: "%.2f", expensesToExport.filter { $0.type == .debit }.reduce(0) { $0 + $1.amount }))")
                    statsRow("Credits", value: "₹\(String(format: "%.2f", expensesToExport.filter { $0.type == .credit }.reduce(0) { $0 + $1.amount }))")
                }

                // ── Filters ──────────────────────────────────────────
                Section("Filters") {
                    Toggle("Filter by Date Range", isOn: $useDateFilter)
                    if useDateFilter {
                        DatePicker("From", selection: $filterStartDate, displayedComponents: .date)
                        DatePicker("To",   selection: $filterEndDate,   displayedComponents: .date)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transaction Type").font(.subheadline).foregroundColor(.secondary)
                        HStack {
                            typeToggle("Debit",   type: .debit,   color: .red)
                            typeToggle("Credit",  type: .credit,  color: .green)
                            typeToggle("Unknown", type: .unknown, color: .gray)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── Export Format ────────────────────────────────────
                Section("Format") {
                    HStack {
                        Image(systemName: "tablecells")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("CSV (Excel Compatible)")
                                .font(.subheadline).bold()
                            Text("Opens in Microsoft Excel, Apple Numbers, Google Sheets")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                // ── Export Button ────────────────────────────────────
                Section {
                    Button {
                        generateAndShare()
                    } label: {
                        if isGenerating {
                            HStack {
                                ProgressView()
                                Text("Generating…").padding(.leading, 8)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Label("Export \(expensesToExport.count) Expense(s)", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(expensesToExport.isEmpty || isGenerating)
                }
            }
            .navigationTitle("Export to Excel")
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: Sub-views

    private func statsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).bold()
        }
    }

    private func typeToggle(_ label: String, type: TransactionType, color: Color) -> some View {
        Button {
            if selectedTypes.contains(type) { selectedTypes.remove(type) }
            else { selectedTypes.insert(type) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedTypes.contains(type) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedTypes.contains(type) ? color : .secondary)
                Text(label)
                    .font(.caption)
                    .foregroundColor(selectedTypes.contains(type) ? color : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTypes.contains(type) ? color.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedTypes.contains(type) ? color.opacity(0.5) : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func generateAndShare() {
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let url = CSVExporter.saveToTempFile(expenses: expensesToExport)
            DispatchQueue.main.async {
                exportURL    = url
                isGenerating = false
                if url != nil { showShareSheet = true }
            }
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
