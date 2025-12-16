//
//  ScanReceiptView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 14/11/2025.
//

import SwiftUI

struct ScanReceiptView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Inputs
    let originalImage: UIImage
    @State var extractedData: ReceiptData
    
    // State
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateAlert = false
    @State private var duplicateReceiptId: String?
    
    // Form States
    @State private var editedMerchant: String
    @State private var editedDate: Date
    @State private var editedTotal: Double
    @State private var editedStoreType: String
    
    // Data Lists
    @State private var storeList: [StoreInfo] = []
    
    @State private var mainCategoryOptions: [String] = []
    @State private var subCategoryOptionsMap: [String: [String]] = [:]
    
    // UI Constants - Pitch Dark Theme
    let mainBg = Color.black
    let cardBg = Color(hex: "111111") // Dark card background
    let accentGreen = Color(hex: "27A565") // Green
    let textWhite = Color.white
    let textGray = Color.gray
    
    init(image: UIImage, data: ReceiptData) {
        self.originalImage = image
        _extractedData = State(initialValue: data)
        _editedMerchant = State(initialValue: data.merchantName ?? "")
        
        // Date Parsing
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let dateStr = data.transactionDate, let date = formatter.date(from: dateStr) {
            _editedDate = State(initialValue: date)
        } else {
            _editedDate = State(initialValue: Date())
        }
        
        _editedTotal = State(initialValue: data.totalAmount ?? 0.0)
        _editedStoreType = State(initialValue: data.storeType ?? "restaurant") 
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                mainBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        lineItemsSection
                    }
                    .padding(.vertical, 24)
                }
                .background(mainBg)
            }
            .navigationTitle("Refine Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(textWhite)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveReceipt) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .font(.custom("FKGroteskTrial-Medium", size: 16))
                                .foregroundColor(accentGreen)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            // Error/Alert Handling
            .alert("Error Saving", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Duplicate Receipt", isPresented: $showingDuplicateAlert) {
                Button("Replace Old", role: .destructive) {
                    saveReceipt(duplicateAction: "replace")
                }
                Button("Keep Both") {
                    saveReceipt(duplicateAction: "keep")
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This receipt seems to be a duplicate. Do you want to replace the existing one or keep both?")
            }
            .onAppear(perform: loadInitialData)
        }
    }
    
    // MARK: - Sub Views
    
    var headerSection: some View {
        // 1. Header Card (Store, Date, Type, Total)
        VStack(alignment: .leading, spacing: 16) {
            
            // Store Name
            VStack(alignment: .leading, spacing: 6) {
                Text("STORE NAME")
                    .font(.custom("FKGroteskTrial-Medium", size: 10))
                    .tracking(2)
                    .foregroundColor(textGray)
                
                HStack(spacing: 12) {
                    // Merchant Logo (Logo.dev)
                    AsyncImage(url: URL(string: "https://img.logo.dev/\(cleanDomain(editedMerchant))?token=pk_Sa5pkb0QQ3CfQPaZgFE7jA&size=60&retina=true")) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else if phase.error != nil || editedMerchant.isEmpty {
                            // Fallback
                            ZStack {
                                Circle().fill(Color.gray.opacity(0.1))
                                Text(editedMerchant.prefix(1).uppercased())
                                    .font(.custom("FKGroteskTrial-Bold", size: 18))
                                    .foregroundColor(textWhite)
                            }
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    
                    SearchablePicker(
                        title: "Select Merchant",
                        placeholder: "Store Name",
                        selection: $editedMerchant,
                        options: merchantNamesList,
                        allowCreate: true,
                        onSelect: { updateMerchantSelection($0) },
                        onCreate: { updateMerchantSelection($0) }
                    )
                }
                .padding(12)
                .background(cardBg)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            
            // Receipt Date
            VStack(alignment: .leading, spacing: 6) {
                Text("RECEIPT DATE")
                    .font(.custom("FKGroteskTrial-Medium", size: 10))
                    .tracking(2)
                    .foregroundColor(textGray)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(textWhite)
                    
                    DatePicker("", selection: $editedDate, displayedComponents: .date)
                        .labelsHidden()
                        .colorScheme(.dark) // Force dark mode picker
                    
                    Spacer()
                }
                .padding(12)
                .background(cardBg)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            
            // Store Type
            VStack(alignment: .leading, spacing: 6) {
                Text("STORE TYPE")
                    .font(.custom("FKGroteskTrial-Medium", size: 10))
                    .tracking(2)
                    .foregroundColor(textGray)
                
                HStack {
                    Image(systemName: "tag")
                        .font(.system(size: 14))
                        .foregroundColor(textWhite)
                        .rotationEffect(.degrees(90))
                    
                    SearchablePicker(
                        title: "Store Type",
                        placeholder: "Type",
                        selection: $editedStoreType,
                        options: ["grocery", "restaurant", "retail", "fuel", "service", "medical", "transport", "other"],
                        allowCreate: true,
                        onCreate: { saveStoreTypeOverride(merchant: editedMerchant, type: $0) }
                    )
                }
                .padding(12)
                .background(cardBg)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentGreen, lineWidth: 1)
                )
            }
            
            // Total
            VStack(alignment: .leading, spacing: 6) {
                Text("TOTAL")
                    .font(.custom("FKGroteskTrial-Medium", size: 10))
                    .tracking(2)
                    .foregroundColor(textGray)
                
                HStack {
                    Text("£")
                        .font(.custom("BerkeleyMono-Regular", size: 16))
                        .foregroundColor(accentGreen)
                    
                    TextField("0.00", value: $editedTotal, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .font(.custom("BerkeleyMono-Regular", size: 18))
                        .foregroundColor(textWhite)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBg)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(Color(hex: "0A0A0A"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    var lineItemsSection: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Line Items")
                    .font(.custom("FKGroteskTrial-Regular", size: 18))
                    .foregroundColor(textWhite)
                
                Spacer()
                
                Button(action: {
                    extractedData.lineItems.append(LineItem(item: "New Item", price: 0.0, quantity: 1, mainCategory: "other", subCategory: "miscellaneous"))
                }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundColor(accentGreen)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // List
            VStack(spacing: 16) {
                ForEach($extractedData.lineItems) { $item in
                    itemRow(for: $item)
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    func itemRow(for item: Binding<LineItem>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Item Name
            TextField("Item Name", text: item.item)
                .font(.custom("FKGroteskTrial-Regular", size: 14))
                .foregroundColor(textWhite)
                .padding(12)
                .background(cardBg)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            
            // Price & Qty Row
            HStack(spacing: 12) {
                // Price
                HStack {
                    Text("£")
                        .font(.custom("BerkeleyMono-Regular", size: 14))
                        .foregroundColor(textGray)
                    TextField("0.00", value: item.price, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .font(.custom("BerkeleyMono-Regular", size: 14))
                        .foregroundColor(textWhite)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(cardBg)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                
                // Qty
                TextField("1", value: item.quantity, format: .number)
                    .keyboardType(.numberPad)
                    .font(.custom("BerkeleyMono-Regular", size: 14))
                    .foregroundColor(textWhite)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(cardBg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            }
            
            // Categories (Pills)
            VStack(spacing: 8) {
                // Main Category
                HStack {
                    Image(systemName: "fork.knife") // Placeholder icon
                        .font(.system(size: 12))
                        .foregroundColor(Color.orange)
                    
                    SearchablePicker(
                        title: "Category",
                        placeholder: "Category",
                        selection: Binding(
                            get: { item.wrappedValue.mainCategory ?? "" },
                            set: { item.wrappedValue.mainCategory = $0 }
                        ),
                        options: mainCategoryOptions,
                        allowCreate: true,
                        onCreate: { newCat in
                            if !mainCategoryOptions.contains(newCat) {
                                mainCategoryOptions.append(newCat)
                            }
                        }
                    )
                }
                .padding(12)
                .background(cardBg)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                
                // Sub Category
                HStack {
                    Image(systemName: "fork.knife") // Placeholder icon
                        .font(.system(size: 12))
                        .foregroundColor(Color.orange)
                    
                    SearchablePicker(
                        title: "Subcategory",
                        placeholder: "Subcategory",
                        selection: Binding(
                            get: { item.wrappedValue.subCategory ?? "" },
                            set: { 
                                item.wrappedValue.subCategory = $0
                                saveUserCategoryPreference(item: item.wrappedValue.item, main: item.wrappedValue.mainCategory, sub: $0)
                            }
                        ),
                        options: getSubOptions(for: item.wrappedValue.mainCategory),
                        allowCreate: true,
                        onCreate: { newSub in
                           // Allow creation
                        }
                    )
                }
                .padding(12)
                .background(cardBg)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            
            // Delete
            Button(action: {
                if let idx = extractedData.lineItems.firstIndex(where: { $0.id == item.wrappedValue.id }) {
                    extractedData.lineItems.remove(at: idx)
                    recalculateTotal()
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(Color.red.opacity(0.6))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color(hex: "0A0A0A")) // Inner card very dark
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper Properties
    var merchantNamesList: [String] {
        // Combine pulled stores with overridden ones locally
        var names = Set(storeList.map { $0.merchantName })
        if !editedMerchant.isEmpty { names.insert(editedMerchant) }
        return Array(names).sorted()
    }
    
    func getSubOptions(for main: String?) -> [String] {
        guard let main = main, !main.isEmpty else { return [] }
        // Flatten various sources
        let key = main.lowercased()
        // Try exact match or lower
        if let subs = subCategoryOptionsMap[main] { return subs }
        if let subs = subCategoryOptionsMap[key] { return subs }
        return []
    }
    
    // MARK: - Logic Helpers
    func cleanDomain(_ name: String) -> String {
        return name.lowercased().filter { $0.isLetter || $0.isNumber } + ".com"
    }

    func loadInitialData() {
        guard let token = authManager.token else {
            print("❌ No token available for loadInitialData")
            return
        }
        print("📥 Fetching receipt metadata...")
        Task {
            // Load Stores
            do {
                let (data, _) = try await APIClient.shared.rawRequest(path: "/api/store-info", token: token)
                if let stores = try? JSONDecoder().decode([StoreInfo].self, from: data) {
                    await MainActor.run { 
                        self.storeList = stores 
                        print("✅ Loaded \(stores.count) stores")
                    }
                } else {
                     print("⚠️ Failed to decode stores. Raw bytes: \(data.count)")
                }
            } catch { print("❌ Failed stores: \(error)") }
            
            // Load Categories
            do {
                let (data, _) = try await APIClient.shared.rawRequest(path: "/api/category-options", token: token)
                if let catResp = try? JSONDecoder().decode(CategoryOptionsResponse.self, from: data) {
                    await MainActor.run {
                        processCategories(catResp)
                        print("✅ Loaded categories")
                    }
                } else {
                     print("⚠️ Failed to decode categories. Raw bytes: \(data.count)")
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
                    // Normalize key to lower for matching? keeping case sensitive for now but grouped
                     var set = subs[m] ?? Set()
                     set.insert(s)
                     subs[m] = set
                }
            }
        }
        
        self.mainCategoryOptions = Array(mains).sorted()
        self.subCategoryOptionsMap = subs.mapValues { Array($0).sorted() }
    }
    
    func updateMerchantSelection(_ new: String) {
        // Logic to check store list and auto-set type
        if let match = storeList.first(where: { $0.merchantName.lowercased() == new.lowercased() }) {
            extractedData.selectedMerchantId = match.id
            if let t = match.storeType {
                editedStoreType = t
            }
            // Logic to update logo etc
        }
    }
    
    func saveStoreTypeOverride(merchant: String, type: String) {
        // Fire and forget
        guard let token = authManager.token else { return }
        let body: [String: String] = ["merchant_name": merchant, "store_type": type]
        Task {
            _ = try? await APIClient.shared.rawRequest(path: "/api/user-store-type-overrides", method: "POST", body: try? JSONEncoder().encode(body), token: token)
        }
    }
    
    func saveUserCategoryPreference(item: String, main: String?, sub: String) {
        guard let main = main, !main.isEmpty, !sub.isEmpty, let token = authManager.token else { return }
         let body: [String: String] = ["item_name": item, "main_category": main, "sub_category": sub]
        Task {
            _ = try? await APIClient.shared.rawRequest(path: "/api/update-user-category", method: "POST", body: try? JSONEncoder().encode(body), token: token)
        }
    }
    
    func recalculateTotal() {
        let sum = extractedData.lineItems.reduce(0.0) { $0 + ($1.price ?? 0) * Double($1.quantity ?? 1) }
        editedTotal = sum
    }
    
    func saveReceipt() {
        saveReceipt(duplicateAction: nil)
    }
    
    func saveReceipt(duplicateAction: String? = nil) {
        guard let token = authManager.token else { return }
        isSaving = true
        
        // 1. Prepare Data
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var finalData = extractedData
        finalData.merchantName = editedMerchant
        finalData.transactionDate = formatter.string(from: editedDate)
        finalData.totalAmount = editedTotal
        finalData.storeType = editedStoreType
        
        // 2. Encode Metadata
        guard let jsonData = try? JSONEncoder().encode(finalData),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let imageData = originalImage.jpegData(compressionQuality: 0.6) else {
            isSaving = false
            return
        }
        
        // 3. Prepare Params
        var params = ["receiptData": jsonString]
        if let action = duplicateAction {
            params["duplicateAction"] = action
        }
        if let existingId = duplicateReceiptId {
            params["existingReceiptId"] = existingId
        }
        
        // 4. Send Request
        Task {
            do {
                let (_, response) = try await APIClient.shared.uploadRequest(
                    path: "/api/receipts",
                    data: imageData,
                    fileName: "receipt.jpg",
                    mimeType: "image/jpeg",
                    parameters: params,
                    token: token
                )
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        await MainActor.run {
                            isSaving = false
                            dismiss()
                        }
                    } else if httpResponse.statusCode == 409 {
                        await MainActor.run {
                            isSaving = false
                            self.duplicateReceiptId = finalData.id // Fallback
                            self.showingDuplicateAlert = true
                        }
                    } else {
                        throw NSError(domain: "Network", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error \(httpResponse.statusCode)"])
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingSaveError = true
                }
            }
        }
    }
}
