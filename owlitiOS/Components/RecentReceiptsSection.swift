import SwiftUI

struct RecentReceiptsSection: View {
    let receipts: [ReceiptData]
    let onEdit: (ReceiptData) -> Void
    let onDelete: (ReceiptData) -> Void
    
    @State private var currentPage = 0
    private let itemsPerPage = 5
    
    @Environment(\.colorScheme) var colorScheme
    private var primaryText: Color { colorScheme == .dark ? .white : .black }
    private var secondaryText: Color { colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6) }
    private var buttonBg: Color { colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                // Title Removed
                Spacer()
                
                // Pagination Controls
                if receipts.count > itemsPerPage {
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation {
                                currentPage = max(0, currentPage - 1)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(currentPage > 0 ? primaryText : secondaryText.opacity(0.3))
                        }
                        .disabled(currentPage == 0)
                        
                        Text("\(currentPage + 1) / \(totalPages)")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(secondaryText)
                        
                        Button(action: {
                            withAnimation {
                                currentPage = min(totalPages - 1, currentPage + 1)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(currentPage < totalPages - 1 ? primaryText : secondaryText.opacity(0.3))
                        }
                        .disabled(currentPage >= totalPages - 1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(buttonBg)
                    .cornerRadius(8)
                }
            }
            
            // List
            if receipts.isEmpty {
                Text("No receipts found.")
                    .font(.custom("FKGroteskTrial-Regular", size: 14))
                    .foregroundColor(secondaryText)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(paginatedReceipts) { receipt in
                        RecentReceiptRow(
                            receipt: receipt,
                            onEdit: { onEdit(receipt) },
                            onDelete: { onDelete(receipt) }
                        )
                    }
                }
                .transition(.opacity) // Smooth transition when page changes
            }
        }
        .padding()
    }
    
    private var totalPages: Int {
        // Ceiling division: (count + itemsPerPage - 1) / itemsPerPage
        return (receipts.count + itemsPerPage - 1) / itemsPerPage
    }
    
    private var paginatedReceipts: [ReceiptData] {
        let startIndex = currentPage * itemsPerPage
        // Ensure index is within bounds
        guard startIndex < receipts.count else { return [] }
        
        let endIndex = min(startIndex + itemsPerPage, receipts.count)
        // Sort by date descending (assuming user wants most recent first, though inputs might already be sorted)
        let sorted = receipts.sorted { ($0.transactionDate ?? "") > ($1.transactionDate ?? "") }
        
        return Array(sorted[startIndex..<endIndex])
    }
}
