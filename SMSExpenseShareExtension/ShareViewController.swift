import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

// MARK: - Share Extension
// Users can long-press a bank SMS in the Messages app,
// tap More… → select messages → Share → SMS Expense Tracker
// This extension receives the text and saves it to the shared App Group.

class ShareViewController: UIViewController {

    static let appGroupID  = "group.com.example.SMSExpenseTracker"
    static let pendingKey  = "pendingSharedMessages"

    override func viewDidLoad() {
        super.viewDidLoad()
        extractSharedText { [weak self] text in
            guard let self = self else { return }
            if let text = text, !text.isEmpty {
                self.saveToSharedContainer(text)
                self.showSuccessAndClose()
            } else {
                self.showErrorAndClose()
            }
        }
    }

    // MARK: Extract text from extension context

    private func extractSharedText(completion: @escaping (String?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            completion(nil); return
        }

        let textType = UTType.plainText.identifier
        let urlType  = UTType.url.identifier

        for attachment in (item.attachments ?? []) {
            if attachment.hasItemConformingToTypeIdentifier(textType) {
                attachment.loadItem(forTypeIdentifier: textType) { data, _ in
                    let text: String?
                    switch data {
                    case let str as String:      text = str
                    case let url as URL:         text = try? String(contentsOf: url)
                    case let data as Data:       text = String(data: data, encoding: .utf8)
                    default:                     text = nil
                    }
                    completion(text)
                }
                return
            }

            if attachment.hasItemConformingToTypeIdentifier(urlType) {
                attachment.loadItem(forTypeIdentifier: urlType) { data, _ in
                    completion((data as? URL)?.absoluteString)
                }
                return
            }
        }

        // Fallback: try content text from the item itself
        completion(item.attributedContentText?.string ?? item.attributedTitle?.string)
    }

    // MARK: Persist to App Group

    private func saveToSharedContainer(_ text: String) {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        var existing = defaults?.stringArray(forKey: Self.pendingKey) ?? []
        existing.append(text)
        defaults?.set(existing, forKey: Self.pendingKey)
        defaults?.synchronize()
    }

    // MARK: UI Feedback

    private func showSuccessAndClose() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "✅ Saved",
                message: "Message saved. Open SMS Expense Tracker to review and add expenses.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open App", style: .default) { [weak self] _ in
                // Deep link into the main app
                if let url = URL(string: "smsexpense://shared") {
                    self?.extensionContext?.open(url, completionHandler: nil)
                }
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            })
            alert.addAction(UIAlertAction(title: "Done", style: .cancel) { [weak self] _ in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            })
            self?.present(alert, animated: true)
        }
    }

    private func showErrorAndClose() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "No Text Found",
                message: "Could not extract text from the shared item.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            })
            self?.present(alert, animated: true)
        }
    }
}
