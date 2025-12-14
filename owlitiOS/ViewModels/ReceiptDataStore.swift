import Foundation
import Combine

@MainActor
final class ReceiptDataStore: ObservableObject {
    @Published private(set) var receipts: [ReceiptRecord] = []
    @Published var isLoading = false
    @Published var lastError: String?

    func refresh(using token: String?) async {
        guard !isLoading else { return }
        guard let token = token else {
            receipts = []
            lastError = "Please sign in to load your receipts."
            return
        }
        isLoading = true
        lastError = nil
        do {
            let records = try await APIClient.shared.fetchReceipts(token: token)
            receipts = records
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
    }

    func append(_ receipt: ReceiptRecord) {
        receipts.insert(receipt, at: 0)
    }
}
