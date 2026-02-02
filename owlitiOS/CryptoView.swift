import SwiftUI

struct CryptoView: View {
    // Inputs
    let initialReceiptData: ReceiptData?
    let receiptImage: UIImage?
    
    // Callbacks
    var onConfirm: ((ReceiptData) -> Void)? = nil // Pass back updated data
    var onEdit: (() -> Void)? = nil // Toggle Full Edit Mode
    
    @Environment(\.dismiss) var dismiss
    
    // Internal State for editing
    @State private var currentReceiptData: ReceiptData?
    @State private var itemToEdit: LineItem? // For Inline Edit Sheet
    
    // Duplicate Detection State
    @State private var showingDuplicateAlert = false
    @State private var duplicateReceiptId: String?
    @State private var isEditingExisting = false
    
    init(receiptData: ReceiptData?, receiptImage: UIImage?, onConfirm: ((ReceiptData) -> Void)? = nil, onEdit: (() -> Void)? = nil) {
        self.initialReceiptData = receiptData
        self.receiptImage = receiptImage
        self.onConfirm = onConfirm
        self.onEdit = onEdit
        
        // Initialize State
        _currentReceiptData = State(initialValue: receiptData)
    }
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var analyticsManager = AnalyticsManager.shared // Observe changes

    // Data Lists (For Editors)
    @State private var mainCategoryOptions: [String] = []
    @State private var subCategoryOptionsMap: [String: [String]] = [:]
    
    // Adaptive Colors (Matching FinancialSummaryView)
    private var adaptiveBg: Color { colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white }
    private var gridLineColor: Color { colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.02) }

    var body: some View {
        ZStack {
            // Background (Matches FinancialSummaryView)
            ZStack {
                adaptiveBg
                MeshGrid(spacing: 5)
                    .stroke(gridLineColor, lineWidth: 0.5)
            }
            .ignoresSafeArea()
            
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    
                    // Duplicate Banner (Redesigned)
                    if let data = currentReceiptData, let _ = data.existingReceiptId, !isEditingExisting {
                        HStack(alignment: .top, spacing: 16) {
                            // 3D Red Icon
                            ZStack {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(hex: "FF453A"))
                                    .shadow(color: Color(hex: "FF453A").opacity(0.4), radius: 4, x: 0, y: 2) // 3D glow/shadow
                            }
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(hex: "FF453A").opacity(0.1))
                            )
                            
                            // Message
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Duplicate Warning")
                                    .font(.custom("FKGroteskTrial-Medium", size: 14))
                                    .foregroundColor(Color(hex: "FF453A")) // Blood Red
                                
                                Text("This looks like a receipt you've already scanned.")
                                    .font(.custom("FKGroteskTrial-Regular", size: 13))
                                    .foregroundColor(Color(hex: "FF453A").opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            ZStack {
                                // Adaptive Background
                                colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
                                
                                // Mesh Texture
                                MeshGrid(spacing: 4.5)
                                    .stroke(
                                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05),
                                        lineWidth: 0.5
                                    )
                            }
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "FF453A").opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                    
                    VStack(spacing: 0) {
                        // 1. Receipt Image Header
                        if let image = receiptImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .overlay(
                                    LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.4)], startPoint: .center, endPoint: .bottom)
                                )
                        }
                        
                        // 2. Receipt Data Table
                        if let data = currentReceiptData {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Receipt Details")
                                    .font(.custom("FKGroteskTrial-Medium", size: 14))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .padding(.top, 16)
                                    .padding(.horizontal, 16)
                                
                                // USING INLINE EDITING
                                ReceiptTableView(
                                    data: data,
                                    onEdit: onEdit, // Full Edit (ScanReceiptView)
                                    onEditItem: { item in
                                        // Trigger Inline Edit
                                        self.itemToEdit = item
                                    },
                                    onDeleteItem: { itemToDelete in
                                        withAnimation {
                                            deleteItem(itemToDelete)
                                        }
                                    },
                                    isDarkMode: true
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                            }
                        } else {
                            // Empty State
                             Text("No Receipt Data")
                                .font(.custom("FKGroteskTrial-Light", size: 18))
                                .foregroundColor(AppTheme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(40)
                        }
                        
                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 16)
                        
                        // 3. Actions (INSIDE Container)
                        HStack(spacing: 16) {
                            // Discard Button
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Discard")
                                    .font(.custom("FKGroteskTrial-Medium", size: 16))
                                    .foregroundColor(Color.red.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        colorScheme == .dark 
                                            ? Color(hex: "161616").opacity(0.5) 
                                            : Color.white
                                    )
                                    .cornerRadius(12)
                            }
                            
                            // Save Button
                            Button(action: {
                                if let finalData = currentReceiptData {
                                    // Duplicate Check
                                    if let existingId = finalData.existingReceiptId, !isEditingExisting {
                                         duplicateReceiptId = existingId
                                         showingDuplicateAlert = true
                                         return
                                    }
                                    
                                    onConfirm?(finalData)
                                }
                                dismiss()
                            }) {
                                Text("Save")
                                    .font(.custom("FKGroteskTrial-Bold", size: 16))
                                    .foregroundColor(Color(hex: "27A565"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        colorScheme == .dark 
                                            ? Color(hex: "161616") 
                                            : Color.white
                                    )
                                    .cornerRadius(12)
                                    .shadow(
                                        color: Color(hex: "27A565").opacity(0.15),
                                        radius: 8, x: 0, y: 4
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "27A565").opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(16)
                    }
                    .background(
                        adaptiveBg // Solid background (Mesh Free)
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 10, x: 0, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.03),
                                        Color.clear,
                                        Color.black.opacity(colorScheme == .dark ? 0.12 : 0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                }
            }
        }


     .navigationBarHidden(true)
     .alert("Receipt Already Found", isPresented: $showingDuplicateAlert) {
        Button("Cancel", role: .cancel) {
            // Just dismiss alert, stay on view
        }
        Button("Replace", role: .destructive) {
            if let data = currentReceiptData {
                onConfirm?(data)
                dismiss() // Dismiss CryptoView
            }
        }
        Button("Edit Existing") {
            if let id = duplicateReceiptId {
                loadAndEditExistingReceipt(existingId: id)
            }
        }
     } message: {
        Text("This receipt already exists in your account. You can cancel, replace the existing receipt, or edit the existing one.")
     }

     .onAppear {
         loadCategories()
         // Load analytics data for normalized naming (Actual Name dropdown)
         Task { await analyticsManager.ensureDataLoaded() }
         
         // Force Sync on Appear (Crucial for Edit Flow)
         if let initData = initialReceiptData {
             print("🔄 CryptoView Appeared: Syncing Data. Merchant: \(initData.merchantName ?? "nil"), Total: \(initData.totalAmount ?? 0)")
             self.currentReceiptData = initData
         }
     }
     // Fix: Sync state when parent passes new data (e.g. after Full Edit)
     .onChange(of: initialReceiptData) { newData in
        if let newData = newData {
            print("🔄 CryptoView onChange: Data Changed. Merchant: \(newData.merchantName ?? "nil")")
            self.currentReceiptData = newData
        }
     }
     // Inline Edit Sheet
     .sheet(item: $itemToEdit) { item in
             EditLineItemView(
                item: Binding(
                    get: { item },
                    set: { _ in } // We handle save in callback
                ),
                mainCategoryOptions: mainCategoryOptions,
                subCategoryOptionsMap: subCategoryOptionsMap,
                normalizedItemOptions: analyticsManager.getUniqueNormalizedItemNames(), // Dynamic link
                onUpdateCategory: { item, main, sub in
                    saveUserCategoryPreference(item: item, main: main, sub: sub)
                },
                onUpdateNormalizedName: { itemName, normalizedName in
                    saveUserItemPreference(itemName: itemName, normalizedName: normalizedName)
                },
                onSave: { updatedItem in
                    updateItem(updatedItem)
                }
             )
             .presentationDetents([.medium, .large])
        }
    }
    
    // Logic
    func deleteItem(_ item: LineItem) {
        guard var data = currentReceiptData else { return }
        if let idx = data.lineItems.firstIndex(where: { $0.id == item.id }) {
            data.lineItems.remove(at: idx)
            // Recalculate Total
            data.totalAmount = data.lineItems.reduce(0) { $0 + ($1.price ?? 0) * Double($1.quantity ?? 1) }
            self.currentReceiptData = data
        }
    }
    
    func updateItem(_ newItem: LineItem) {
        guard var data = currentReceiptData else { return }
        if let idx = data.lineItems.firstIndex(where: { $0.id == newItem.id }) {
            data.lineItems[idx] = newItem
            // Recalculate Total
            data.totalAmount = data.lineItems.reduce(0) { $0 + ($1.price ?? 0) * Double($1.quantity ?? 1) }
            self.currentReceiptData = data
        }
    }
    
    // MARK: - Category Logic
    func loadCategories() {
        guard let token = authManager.token else { return }
        print("📥 Fetching categories (CryptoView)...")
        Task {
            do {
                let (data, _) = try await APIClient.shared.rawRequest(path: "/api/category-options", token: token)
                if let catResp = try? JSONDecoder().decode(CategoryOptionsResponse.self, from: data) {
                    await MainActor.run {
                        processCategories(catResp)
                        print("✅ Loaded categories (CryptoView)")
                    }
                }
            } catch { print("❌ Failed categories: \(error)") }
        }
    }
    
    func processCategories(_ resp: CategoryOptionsResponse) {
        var mains = Set<String>()
        var subs = [String: Set<String>]()
        
        let allws = resp.userCategories + resp.masterCategories
        for row in allws {
            if let m = row.mainCategory, !m.isEmpty {
                mains.insert(m)
                if let s = row.subCategory, !s.isEmpty {
                     var set = subs[m] ?? Set()
                     set.insert(s)
                     subs[m] = set
                }
            }
        }
        
        self.mainCategoryOptions = Array(mains).sorted()
        self.subCategoryOptionsMap = subs.mapValues { Array($0).sorted() }
    }
    
    func saveUserCategoryPreference(item: String, main: String?, sub: String) {
        guard let main = main, !main.isEmpty, !sub.isEmpty, let token = authManager.token else { return }
         let body: [String: String] = ["item_name": item, "main_category": main, "sub_category": sub]
        Task {
            _ = try? await APIClient.shared.rawRequest(path: "/api/update-user-category", method: "POST", body: try? JSONEncoder().encode(body), token: token)
        }
    }

    func saveUserItemPreference(itemName: String, normalizedName: String) {
        guard !itemName.isEmpty, !normalizedName.isEmpty, let token = authManager.token else { return }
        Task {
            do {
                try await APIClient.shared.saveUserItemRename(
                    itemName: itemName,
                    normalizedName: normalizedName,
                    token: token
                )
                print("✅ User item preference saved.")
            } catch {
                print("❌ Failed to save user item preference: \(error)")
            }
        }
    }
    
    // MARK: - Duplicate Handling
    
    func loadAndEditExistingReceipt(existingId: String) {
        guard let token = authManager.token else { return }
        print("📥 Loading existing receipt for edit: \(existingId)")
        
        Task {
            do {
                let (data, response) = try await APIClient.shared.rawRequest(
                    path: "/api/receipts/\(existingId)",
                    token: token
                )
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let receiptJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("✅ CryptoView: Loaded existing receipt data")
                        
                        // Parse manually to ensure we Capture Everything
                        // NOTE: Using JSONDecoder implies strict structure, manual parse matches ScanReceiptView flexibility
                        // But let's try to map it to our struct cleaner if possible.
                        // For now, reuse the parsing logic that works.
                        
                        var existingReceipt = ReceiptData()
                        existingReceipt.existingReceiptId = receiptJson["id"] as? String // IMPORTANT: Set this for Update logic
                        existingReceipt.id = receiptJson["id"] as? String
                        existingReceipt.merchantName = receiptJson["merchant_name"] as? String
                        existingReceipt.transactionDate = receiptJson["transaction_date"] as? String
                        existingReceipt.totalAmount = receiptJson["total_amount"] as? Double
                        existingReceipt.storeType = receiptJson["store_type"] as? String
                        
                        if let lineItemsJson = receiptJson["line_items"] as? [[String: Any]] {
                            existingReceipt.lineItems = lineItemsJson.compactMap { itemJson in
                                guard let itemName = itemJson["item"] as? String ?? itemJson["name"] as? String else { return nil }
                                return LineItem(
                                    item: itemName,
                                    price: itemJson["price"] as? Double ?? 0.0,
                                    quantity: itemJson["quantity"] as? Int ?? 1,
                                    mainCategory: itemJson["mainCategory"] as? String ?? itemJson["main_category"] as? String,
                                    subCategory: itemJson["subCategory"] as? String ?? itemJson["sub_category"] as? String
                                )
                            }
                        }
                        
                        await MainActor.run {
                            self.currentReceiptData = existingReceipt
                            self.isEditingExisting = true // FLAG: We are now intentionally editing
                            
                            // Clear alert state
                            self.duplicateReceiptId = nil
                            self.showingDuplicateAlert = false
                        }
                    }
                }
            } catch {
                 print("❌ Failed to load existing receipt: \(error)")
            }
        }
    }
}

struct CryptoView_Previews: PreviewProvider {
    static var previews: some View {
        CryptoView(receiptData: nil, receiptImage: nil)
            .preferredColorScheme(.dark)
            .environmentObject(AuthManager())
    }
}
