import SwiftUI

struct ReceiptHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authManager: AuthManager
    
    // Theme
    @AppStorage("isDarkMode") var isDarkMode = true
    
    // Data
    @State private var groupedReceipts: [(key: String, value: [ReceiptData])] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Action State
    @State private var receiptToEdit: ReceiptData?
    @State private var showEditSheet = false
    @State private var receiptIdToDelete: String?
    @State private var showDeleteAlert = false
    
    var themeBackground: Color { isDarkMode ? .black : Color(hex: "FAFAF5") }
    var themeText: Color { isDarkMode ? .white : .black }
    var themeSecondaryBackground: Color { isDarkMode ? Color(white: 0.12) : .white }
    var themeHeaderBackground: Color { isDarkMode ? Color.black.opacity(0.95) : Color(hex: "FAFAF5").opacity(0.95) }
    private var gridLineColor: Color { isDarkMode ? Color.white.opacity(0.035) : Color.black.opacity(0.02) }

    var body: some View {
        ZStack {
            // Background matching the app theme
            ZStack {
                themeBackground
                MeshGrid(spacing: 8)
                    .stroke(gridLineColor, lineWidth: 0.5)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.custom("FKGroteskTrial-Regular", size: 16))
                        .foregroundColor(themeText.opacity(0.7))
                        .padding(8)
                        .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    Text("History")
                        .font(.custom("FKGroteskTrial-Bold", size: 18))
                        .foregroundColor(themeText)
                    
                    Spacer()
                    
                    // Balance Spacer
                    Color.clear.frame(width: 60, height: 40)
                }
                .padding()
                .background(themeHeaderBackground)
                
                // MARK: - Content
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.gray)
                        Button("Retry") {
                            Task { await loadData() }
                        }
                    }
                    Spacer()
                } else if groupedReceipts.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No receipts found")
                            .font(.custom("FKGroteskTrial-Regular", size: 16))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                            ForEach(groupedReceipts, id: \.key) { (sectionHeader, receipts) in
                                Section(header: 
                                    HStack {
                                        Text(sectionHeader)
                                            .font(.custom("FKGroteskTrial-Bold", size: 14))
                                            .foregroundColor(themeText)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(isDarkMode ? Color(hex: "1C1C1E") : Color.white) // Card/Pill BG
                                            .cornerRadius(8)
                                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                                        
                                        VStack { Divider().background(themeText.opacity(0.1)) }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 16)
                                    .background(themeHeaderBackground) // Stickiness bg
                                ) {
                                    ForEach(receipts) { receipt in
                                        ReceiptTableView(
                                            data: receipt,
                                            onEdit: {
                                                self.receiptToEdit = receipt
                                                self.showEditSheet = true
                                            },
                                            onDelete: {
                                                self.receiptIdToDelete = receipt.id
                                                self.showDeleteAlert = true
                                            }
                                        )
                                        .padding(.horizontal)
                                        .padding(.bottom, 8)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditSheet) {
            if var receipt = receiptToEdit {
                 // Ensure ID is set for update
                 let _ = { receipt.existingReceiptId = receipt.id }()
                 ScanReceiptView(image: UIImage(), data: receipt, saveMode: .server) { _ in
                     // Reload data on save
                     Task { await loadData() }
                 }
            }
        }
        .alert("Delete Receipt", isPresented: $showDeleteAlert) {
             Button("Cancel", role: .cancel) { }
             Button("Delete", role: .destructive) {
                 if let id = receiptIdToDelete {
                     performDelete(id: id)
                 }
             }
        } message: {
             Text("Are you sure you want to delete this receipt? This action cannot be undone.")
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Actions
    private func performDelete(id: String) {
        guard let token = authManager.token else { return }
        Task {
            do {
                try await APIClient.shared.deleteReceipt(receiptId: id, token: token)
                await loadData() // Reload fully to refresh grouping
            } catch {
                print("Failed to delete receipt: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to delete: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Data Loading & Grouping
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        guard let token = authManager.token else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }
        
        do {
            // 1. Fetch all receipts
            // Note: Currently fetchReceipts fetches everything. 
            // In a real app we might paginate, but sticking to existing pattern for now.
            let allReceipts = try await APIClient.shared.fetchReceipts(token: token)
            
            // 2. Sort & Group
            let processed = processReceipts(allReceipts)
            
            await MainActor.run {
                self.groupedReceipts = processed
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func processReceipts(_ receipts: [ReceiptData]) -> [(key: String, value: [ReceiptData])] {
        let sorted = receipts.sorted { 
            ($0.transactionDate ?? "") > ($1.transactionDate ?? "") 
        }
        
        let grouped = Dictionary(grouping: sorted) { receipt -> String in
            guard let dateStr = receipt.transactionDate else { return "Unknown Date" }
            return formatDateHeader(dateStr)
        }
        
        // Sort keys (Dates) descending
        // "Today", "Yesterday", "MMM d, yyyy"
        // We need a way to sort the resulting keys logically, not alphabetically.
        // It's easier if we iterate the sorted list and build the array.
        
        var result: [(key: String, value: [ReceiptData])] = []
        var currentSection: String? = nil
        var currentItems: [ReceiptData] = []
        
        for receipt in sorted {
            let header = formatDateHeader(receipt.transactionDate)
            
            if header != currentSection {
                if let sec = currentSection {
                    result.append((key: sec, value: currentItems))
                }
                currentSection = header
                currentItems = [receipt]
            } else {
                currentItems.append(receipt)
            }
        }
        
        // Append last
        if let sec = currentSection {
            result.append((key: sec, value: currentItems))
        }
        
        return result
    }
    
    private func formatDateHeader(_ dateStr: String?) -> String {
        guard let dateStr = dateStr, let date = parseDate(dateStr) else { return "Unknown Date" }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func parseDate(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)
    }
}

#Preview {
    ReceiptHistoryView()
        .environmentObject(AuthManager())
}
