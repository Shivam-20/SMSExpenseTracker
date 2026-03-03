import SwiftUI

@main
struct SMSExpenseTrackerApp: App {
    @StateObject private var store   = ExpenseStore.shared
    @StateObject private var pending = PendingMessagesHandler.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(pending)
                .onOpenURL { url in
                    // Called when Share Extension opens the app via smsexpense:// scheme
                    if url.scheme == "smsexpense" {
                        pending.checkForPendingMessages()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Also check on every foreground to catch any missed messages
                    pending.checkForPendingMessages()
                }
        }
    }
}

