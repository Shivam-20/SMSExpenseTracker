# SMS Expense Tracker — iOS App

Scan bank/transaction SMS messages, extract expense data automatically, and export to Excel (CSV).

---

## Features

- 📋 **Paste SMS text** — paste one or many bank messages at once; the parser extracts all expenses
- 📤 **Share Extension** — share messages directly from the iOS Messages app without copy-paste
- 🔍 **Smart parsing** — detects amount, merchant, date, bank, debit/credit, and auto-categorises
- 🌍 **Multi-currency** — ₹ INR, $ USD, € EUR, £ GBP auto-detected
- 📁 **Categories** — Food, Shopping, Transport, Utilities, Entertainment, Healthcare, Finance
- ✏️ **Edit & delete** — correct any misread data
- 📊 **Export to CSV** — opens in Microsoft Excel, Apple Numbers, Google Sheets
- 📆 **Date & type filters** — export only the transactions you need

---

## Project Structure

```
SMSExpenseTracker/
├── SMSExpenseTracker/                  ← Main app target
│   ├── SMSExpenseTrackerApp.swift      ← App entry point
│   ├── ContentView.swift               ← Tab bar + pending sheet
│   ├── Info.plist
│   ├── Models/
│   │   └── Expense.swift              ← Data model
│   ├── Services/
│   │   ├── SMSParser.swift            ← Regex-based SMS parser
│   │   ├── ExpenseStore.swift         ← JSON persistence (App Group)
│   │   ├── CSVExporter.swift          ← CSV/Excel generator
│   │   └── PendingMessagesHandler.swift
│   └── Views/
│       ├── ExpenseListView.swift
│       ├── AddExpenseView.swift
│       ├── ExpenseDetailView.swift
│       └── ExportView.swift
└── SMSExpenseShareExtension/           ← Share Extension target
    ├── ShareViewController.swift
    └── Info.plist
```

---

## Xcode Setup (Step by Step)

### 1. Create the Xcode Project

1. Open **Xcode → File → New → Project**
2. Choose **iOS → App**
3. Fill in:
   - **Product Name:** `SMSExpenseTracker`
   - **Bundle ID:** `com.yourapp.SMSExpenseTracker` *(replace `yourapp` with your own)*
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Minimum Deployment Target:** iOS 16.0+
4. Save the project

### 2. Add Source Files

1. Delete the default `ContentView.swift` Xcode created
2. Drag all files from `SMSExpenseTracker/` (in this repo) into the Xcode project navigator
3. Create Groups (folders) matching the directory structure if desired
4. Make sure **Target Membership** is set to `SMSExpenseTracker` for all files

### 3. Configure App Group (for Share Extension)

1. In Xcode, select your **project** → **SMSExpenseTracker** target → **Signing & Capabilities**
2. Click **+ Capability** → add **App Groups**
3. Create a group: `group.com.yourapp.SMSExpenseTracker`
4. Do the same for the Share Extension target (step 5)

### 4. Add the Share Extension Target

1. **File → New → Target**
2. Choose **iOS → Share Extension**
3. Name it: `SMSExpenseShareExtension`
4. Set **Bundle ID:** `com.yourapp.SMSExpenseTracker.ShareExtension`
5. Replace the generated `ShareViewController.swift` with the one in this repo
6. Replace `Info.plist` with the one from `SMSExpenseShareExtension/`
7. Add **App Groups** capability to this target (same group ID as above)

### 5. Update Bundle IDs & App Group ID

In **3 places**, replace `com.yourapp` with your actual bundle ID prefix:

| File | String to update |
|------|-----------------|
| `ExpenseStore.swift` | `group.com.yourapp.SMSExpenseTracker` |
| `PendingMessagesHandler.swift` | `group.com.yourapp.SMSExpenseTracker` |
| `ShareViewController.swift` | `group.com.yourapp.SMSExpenseTracker` |

### 6. Build & Run

- Select an **iPhone simulator or device** (iOS 16+)
- **Cmd+R** to build and run
- The app will install with both the main app and the Share Extension

---

## How to Use

### Option A — Paste SMS Text

1. Open the app → tap **Scan SMS**
2. Paste one or more bank messages into the text box
3. Tap **Analyse** — the app detects and previews all expenses
4. Select the ones you want → tap **Add**

### Option B — Share from Messages App

1. Open the **Messages** app on your iPhone
2. Long-press a bank SMS → tap **More…**
3. Select one or multiple messages
4. Tap the **Share** (↑) button → choose **SMS Expense Tracker**
5. Tap **Open App** — the expenses are shown for review

### Export to Excel

1. Tap the **Export** tab
2. Optionally filter by date range or transaction type
3. Tap **Export** — the CSV file opens in the iOS share sheet
4. Save to **Files**, AirDrop, email, or open directly in Excel

---

## Sample SMS Messages (for testing)

```
Your A/C XX1234 is debited by ₹2,500.00 on 01-Jan-2025 at ZOMATO. Avbl Bal: ₹45,200

Dear Customer, INR 1250.00 has been debited from your account ending 5678 for purchase at AMAZON on 02/01/2025.

Your HDFC Bank Credit Card ending 9012 has been charged $45.99 at NETFLIX on 03-01-2025.

Txn of Rs.850 done from your SBI account. Transferred to UBER on 04/01/2025.

A/C XX3456 credited with ₹5,000.00 on 05-Jan-2025. Refund from SWIGGY.
```

---

## Supported SMS Formats

The parser handles messages from:
- HDFC, ICICI, SBI, Axis, Kotak, PNB, Canara, IndusInd, Yes Bank
- Paytm, Google Pay (GPay), PhonePe, Amazon Pay
- Chase, Citibank, Wells Fargo, Barclays
- Any message containing amount + transaction keywords

### Recognised Keywords
`debited`, `credited`, `spent`, `paid`, `payment`, `purchase`, `transaction`, `withdrawn`, `transferred`, `charged`, `deducted`, `received`, `refund`, `cashback`

### Currency Symbols Detected
`₹` / `Rs.` / `INR` — Indian Rupee  
`$` / `USD` — US Dollar  
`€` / `EUR` — Euro  
`£` / `GBP` — British Pound  

---

## Requirements

- **Xcode** 15+
- **iOS** 16.0+
- **Swift** 5.9+
- No third-party dependencies — pure Swift + SwiftUI

---

## Privacy

- No data ever leaves your device
- All expenses stored locally in the App Group container (JSON file)
- No analytics, no network requests
