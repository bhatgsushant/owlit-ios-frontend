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
    @Environment(\.colorScheme) var colorScheme
    
    // Inputs
    let originalImage: UIImage
    @State var extractedData: ReceiptData
    var onSaveSuccess: ((ReceiptData) -> Void)? // Callback
    var onCancel: (() -> Void)? // Callback for cancellation
    
    enum SaveMode {
        case server
        case local
    }
    // Safety: Default to local to prevent accidental uploads/duplicates from Scan Flow
    var saveMode: SaveMode = .local

    // State
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateAlert = false
    @State private var duplicateReceiptId: String?
    @State private var existingReceiptToEdit: ReceiptData?
    @State private var showingExistingReceipt = false
    @State private var showingDatePicker = false
    
    // Form States
    @State private var editedMerchant: String
    @State private var editedDate: Date
    @State private var editedTotal: Double
    @State private var editedStoreType: String
    
    // Data Lists
    @State private var storeList: [StoreInfo] = []
    
    @State private var mainCategoryOptions: [String] = []
    @State private var subCategoryOptionsMap: [String: [String]] = [:]
    @State private var storeTypeOptions: [String] = []
    
    // UI Constants - Adaptive Theme
    var mainBg: Color { colorScheme == .dark ? Color.black : Color(hex: "F7F5FF") }
    var cardBg: Color { colorScheme == .dark ? Color(hex: "111111") : Color.white }
    var accentGreen: Color { Color(hex: "27A565") }
    var textPrimary: Color { colorScheme == .dark ? Color(hex: "E5E5E5") : Color.black }
    var textSecondary: Color { Color.gray }
    var strokeColor: Color { colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05) }
    
    init(image: UIImage, data: ReceiptData) {
        let finalImage: UIImage
        if image.cgImage == nil && image.ciImage == nil {
             print("❌ WARNING: ScanReceiptView received empty/invalid UIImage")
             // Try to recover from Singleton
             if let recovered = ImageTransfer.shared.pendingImage {
                 print("✅ ScanReceiptView: Recovered Image from Singleton in Init!")
                 finalImage = recovered
             } else {
                 finalImage = image
             }
        } else {
             finalImage = image 
        }
        self.originalImage = finalImage
        
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
    
    // Convenience init for optional callback
    init(image: UIImage, data: ReceiptData, saveMode: SaveMode = .local, onSaveSuccess: ((ReceiptData) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.init(image: image, data: data)
        self.saveMode = saveMode
        self.onSaveSuccess = onSaveSuccess
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ZStack {
                    mainBg
                    
                    MeshGrid(spacing: 4.5)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {

                        storeLogoView
                        headerSection
                        lineItemsSection
                        
                        // Spacer to push buttons down slightly
                        Color.clear.frame(height: 20)
                        
                        // Bottom Action Buttons
                        HStack(spacing: 12) {
                            // Cancel (Nevermind Style)
                            Button(action: {
                                if let onCancel = onCancel {
                                    onCancel()
                                } else {
                                    dismiss()
                                }
                            }) {
                                Text("CANCEL")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(colorScheme == .dark ? Color(hex: "292929") : Color(hex: "F7F7F2"))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(colorScheme == .dark ? Color.clear : .white, lineWidth: 1.5)
                                    )
                            }
                            
                            // Save (Primary Style)
                            Button(action: saveReceipt) {
                                Group {
                                    if isSaving {
                                        ProgressView()
                                            .tint(colorScheme == .dark ? .black : .white)
                                    } else {
                                        Text("SAVE")
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .tracking(0.5)
                                            .foregroundColor(colorScheme == .dark ? .black.opacity(0.6) : .white.opacity(0.8))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(colorScheme == .dark ? Color.orange : Color.black)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.2), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isSaving)
                            .opacity(isSaving ? 0.7 : 1.0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively) // Allow scrolling to dismiss
                .onTapGesture {
                    hideKeyboard()
                }
            }
            // .navigationTitle("E D I T  R E C E I P T") // Replaced with ToolbarItem
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EDIT RECEIPT")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.6))
                }
            }
            // Error/Alert Handling
            .alert("Error Saving", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Receipt Already Found", isPresented: $showingDuplicateAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Replace", role: .destructive) {
                    saveReceipt(duplicateAction: "replace")
                }
                Button("Edit Existing") {
                    loadAndEditExistingReceipt()
                }
            } message: {
                Text("This receipt already exists in your account. You can cancel, replace the existing receipt, or edit the existing one.")
            }
            .sheet(isPresented: $showingExistingReceipt) {
                if let existingReceipt = existingReceiptToEdit {
                    ScanReceiptView(
                        image: originalImage,
                        data: existingReceipt,
                        saveMode: .server, // Explicitly use server mode for existing receipts
                        onSaveSuccess: { updatedData in
                            self.onSaveSuccess?(updatedData)
                            dismiss()
                        }
                    )
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                VStack {
                    DatePicker("Select Date", selection: $editedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    
                    Button("Done") {
                        showingDatePicker = false
                    }
                    .font(.headline)
                    .padding()
                }
                .presentationDetents([.medium])
            }
            .onAppear(perform: loadInitialData)
        }
    }
    
    // MARK: - Sub Views
    

    
    var headerSection: some View {
        // 1. Header Card (Grid Only - Logo moved to top)
        VStack(alignment: .leading, spacing: 12) {
            
                // Row 1: Store Name | Store Type
                HStack(alignment: .top, spacing: 12) {
                    // Store Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("STORE NAME")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.8))
                        
                        SearchablePicker(
                            title: "Select Merchant",
                            placeholder: "Store Name",
                            selection: $editedMerchant,
                            options: merchantNamesList,
                            allowCreate: true,
                            onSelect: { updateMerchantSelection($0) },
                            onCreate: { updateMerchantSelection($0) },
                            fontSize: 12
                        )
                        .padding(12)
                        .frame(height: 50)
                        .background(
                            ZStack {
                                cardBg
                                MeshGrid(spacing: 2)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
                            }
                        )
                        .cornerRadius(16)
                        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(strokeColor, lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Store Type
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TYPE")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.8))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.system(size: 12))
                                .foregroundColor(colorScheme == .dark ? textPrimary : .black)
                                .rotationEffect(.degrees(90))
                            
                            SearchablePicker(
                                title: "Type",
                                placeholder: "Type",
                                selection: Binding(
                                    get: { editedStoreType.uppercased() },
                                    set: { editedStoreType = $0 }
                                ),
                                options: (storeTypeOptions.isEmpty ? ["grocery", "restaurant", "retail", "fuel", "service", "medical", "transport", "other"] : storeTypeOptions).map { $0.uppercased() },
                                allowCreate: true,
                                onCreate: { saveStoreTypeOverride(merchant: editedMerchant, type: $0) },
                                fontSize: 12
                            )
                        }
                        .padding(12)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity) // Make it flexible to match Store Name
                        .background(
                            ZStack {
                                cardBg
                                MeshGrid(spacing: 2)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
                            }
                        )
                        .cornerRadius(16)
                        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(strokeColor, lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity)
                }
            
            // Row 2: Date | Total
            HStack(alignment: .top, spacing: 12) {
                // Receipt Date
                VStack(alignment: .leading, spacing: 6) {
                    Text("DATE")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.8))
                    
                    Button(action: {
                        showingDatePicker = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                                .foregroundColor(textPrimary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(dateFormatter.string(from: editedDate))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundColor(colorScheme == .dark ? textPrimary.opacity(0.6) : .black.opacity(0.9))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .frame(height: 50)
                        .background(
                            ZStack {
                                cardBg
                                MeshGrid(spacing: 2)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
                            }
                        )
                        .cornerRadius(16)
                        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(strokeColor, lineWidth: 1))
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Total
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOTAL")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.8))
                    
                    HStack(spacing: 4) {
                        Text("£")
                            .font(.custom("BerkeleyMono-Regular", size: 14))
                            .foregroundColor(accentGreen)
                        
                        TextField("0.00", value: $editedTotal, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .font(.system(size: 14, weight: .medium, design: .monospaced)) // Apply monospaced system font
                            .tracking(0.5) // Apply tracking
                            .foregroundColor(colorScheme == .dark ? textPrimary.opacity(0.6) : .black.opacity(0.9)) // Apply reduced opacity
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .frame(height: 50)
                    .background(
                        ZStack {
                            cardBg
                            MeshGrid(spacing: 2)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
                        }
                    )
                    .cornerRadius(16)
                    .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(strokeColor, lineWidth: 1))
                }
                .frame(maxWidth: .infinity)
            }
        }

        .padding(20)
        .background(
            colorScheme == .dark ? Color(hex: "1C1A22") : Color(hex: "F8F8F8")
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.12), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(strokeColor, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    var storeLogoView: some View {
        HStack {
            // Merchant Logo (Logo.dev)
            let logoDomain = AnalyticsManager.shared.getDomain(for: editedMerchant) ?? cleanDomain(editedMerchant)
            AsyncImage(url: URL(string: "https://img.logo.dev/\(logoDomain)?token=pk_Sa5pkb0QQ3CfQPaZgFE7jA&size=80&retina=true")) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else if phase.error != nil || editedMerchant.isEmpty {
                    // Fallback
                    ZStack {
                        Circle().fill(Color.gray.opacity(0.1))
                        Text(editedMerchant.prefix(1).uppercased())
                            .font(.custom("FKGroteskTrial-Bold", size: 18))
                            .foregroundColor(textPrimary)
                    }
                } else {
                    ProgressView()
                }
            }
            .frame(width: 40, height: 40)
            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            .clipShape(Circle())
            .overlay(Circle().stroke(strokeColor, lineWidth: 1))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 4, x: 0, y: 2)
            
            Spacer()
        }
        // .padding(.top, 10) // Removed to reduce header space
        .padding(.leading, 20) // Align with card leading
    }
    
    var lineItemsSection: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("LINE ITEMS")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.8))
                
                Spacer()
                
                Button(action: {
                    extractedData.lineItems.insert(LineItem(item: "New Item", price: 0.0, quantity: 1, mainCategory: "other", subCategory: "miscellaneous"), at: 0)
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
                ForEach(Array($extractedData.lineItems.enumerated()), id: \.element.id) { index, $item in
                    ReceiptLineItemRow(
                        item: $item,
                        mainCategoryOptions: mainCategoryOptions,
                        subCategoryOptionsMap: subCategoryOptionsMap,
                        onDelete: {
                            if let idx = extractedData.lineItems.firstIndex(where: { $0.id == item.id }) {
                                extractedData.lineItems.remove(at: idx)
                                recalculateTotal()
                            }
                        },
                        onUpdateCategory: { item, main, sub in
                            saveUserCategoryPreference(item: item, main: main, sub: sub)
                        }
                    )
                    
                    // Separator with Serial Number (Always show, acts as footer for the item)
                    HStack(spacing: 12) {
                        DashedLine()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .frame(height: 1)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.2)) // Lighter in Dark Mode, Subtler in Light
                        
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            )
                        
                        DashedLine()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .frame(height: 1)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.2)) // Lighter in Dark Mode, Subtler in Light
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(20)
            .background(
                colorScheme == .dark ? Color(hex: "1C1A22") : Color(hex: "FDFCFA")
            )
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.12), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white, lineWidth: 1.5)
            )
            .padding(.horizontal, 16)

        }
        .onChange(of: extractedData.lineItems) { _ in
            recalculateTotal()
        }
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
            

            
            // Load Store Types (From AnalyticsManager which aggregates API + History)
            await AnalyticsManager.shared.ensureDataLoaded()
            let types = AnalyticsManager.shared.getAvailableStoreTypes()
            await MainActor.run {
                self.storeTypeOptions = types
            }
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
        }
        
        // Auto-fill Store Type from AnalyticsManager (History Priority)
        if let type = AnalyticsManager.shared.getStoreCategory(for: new) {
             editedStoreType = type.lowercased()
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
    
    func loadAndEditExistingReceipt() {
        guard let existingId = duplicateReceiptId,
              let token = authManager.token else {
            print("❌ Missing duplicate receipt ID or token")
            return
        }
        
        print("📥 Loading existing receipt: \(existingId)")
        
        Task {
            do {
                let (data, response) = try await APIClient.shared.rawRequest(
                    path: "/api/receipts/\(existingId)",
                    token: token
                )
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 Fetch Receipt Response: Status \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        // Parse the receipt data
                        if let receiptJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("✅ Loaded existing receipt data")
                            
                            // Convert to ReceiptData
                            var existingReceipt = ReceiptData()
                            existingReceipt.existingReceiptId = receiptJson["id"] as? String
                            existingReceipt.merchantName = receiptJson["merchant_name"] as? String
                            existingReceipt.transactionDate = receiptJson["transaction_date"] as? String
                            existingReceipt.totalAmount = receiptJson["total_amount"] as? Double
                            existingReceipt.storeType = receiptJson["store_type"] as? String
                            
                            // Parse line items
                            if let lineItemsJson = receiptJson["line_items"] as? [[String: Any]] {
                                existingReceipt.lineItems = lineItemsJson.compactMap { itemJson in
                                    guard let itemName = itemJson["item"] as? String ?? itemJson["name"] as? String else {
                                        return nil
                                    }
                                    
                                    let price = itemJson["price"] as? Double ?? 0.0
                                    let quantity = itemJson["quantity"] as? Int ?? 1
                                    let mainCategory = itemJson["mainCategory"] as? String ?? itemJson["main_category"] as? String
                                    let subCategory = itemJson["subCategory"] as? String ?? itemJson["sub_category"] as? String
                                    
                                    return LineItem(
                                        item: itemName,
                                        price: price,
                                        quantity: quantity,
                                        mainCategory: mainCategory,
                                        subCategory: subCategory
                                    )
                                }
                            }
                            
                            await MainActor.run {
                                self.existingReceiptToEdit = existingReceipt
                                self.showingExistingReceipt = true
                            }
                        }
                    } else {
                        throw NSError(domain: "Network", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch receipt"])
                    }
                }
            } catch {
                print("❌ Error loading existing receipt: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to load existing receipt: \(error.localizedDescription)"
                    showingSaveError = true
                }
            }
        }
    }

    
    func saveReceipt() {
        // If we have an existingReceiptId...
        if let dupId = extractedData.existingReceiptId {
            
            // If we are in .local mode (Initial Scan), we must prompt the user.
            if saveMode == .local {
                duplicateReceiptId = dupId
                showingDuplicateAlert = true
                return
            }
            
            // If we are in .server mode (e.g., explicit Edit Existing flow), 
            // we treat this as an intentional update (Replace).
            saveReceipt(duplicateAction: "replace")
            
        } else {
            saveReceipt(duplicateAction: nil)
        }
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
        finalData.originalImage = self.originalImage
        
        // 2. Encode Metadata
        do {
            let jsonData = try JSONEncoder().encode(finalData)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("❌ Failed to convert JSON data to string")
                errorMessage = "Failed to process receipt data (Encoding Error)"
                showingSaveError = true
                isSaving = false
                return
            }
            
            // 3. Prepare Image (Optional if editing)
            var imageData = originalImage.jpegData(compressionQuality: 0.6)
            
            // If failed to get data from local image object, try Singleton fallback
            if imageData == nil {
                if let recovered = ImageTransfer.shared.pendingImage {
                    imageData = recovered.jpegData(compressionQuality: 0.6)
                }
            }
            
            // FINAL VALIDATION: Only block if it's a NEW receipt. 
            // If we are UPDATING (existingReceiptId != nil), we can proceed without image data (the server keeps the existing one).
            if imageData == nil && finalData.existingReceiptId == nil {
                print("❌ Failed to process receipt image and no existing ID found")
                errorMessage = "Failed to process receipt image. The image may be missing or invalid."
                showingSaveError = true
                isSaving = false
                return
            }
            
            // 4. Send Request or Save Local
            print("🛑 Debug: ScanReceiptView.saveReceipt called. Mode: \(saveMode)")
            if saveMode == .local {
                print("💾 Saving Locally (No Upload)")
                self.onSaveSuccess?(finalData)
                isSaving = false
                // Do NOT dismiss here. Parent (ChatView) handles state switch back to Preview.
            } else {
                saveReceiptRequest(jsonString: jsonString, imageData: imageData, duplicateAction: duplicateAction, token: token, finalData: finalData)
            }
            
        } catch {
            print("❌ JSON Encoding Error: \(error)")
            errorMessage = "Failed to encode receipt: \(error.localizedDescription)"
            showingSaveError = true
            isSaving = false
            return
        }
    }
    
    func saveReceiptRequest(jsonString: String, imageData: Data?, duplicateAction: String?, token: String, finalData: ReceiptData) {
        var params = ["receiptData": jsonString]
        if let action = duplicateAction {
            params["duplicateAction"] = action
        }
        if let existingId = duplicateReceiptId ?? finalData.existingReceiptId {
            params["existingReceiptId"] = existingId
        }
        
        // 4. Send Request
        Task {
            do {
                let (responseData, response) = try await APIClient.shared.uploadRequest(
                    path: "/api/receipts",
                    data: imageData,
                    fileName: "receipt.jpg",
                    fieldName: "receiptImage",
                    mimeType: "image/jpeg",
                    parameters: params,
                    token: token
                )
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 Save Receipt Response: Status \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                         // Check for Loose Duplicate Flag in Response
                        var updatedData = finalData // Mutable Copy
                        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                             print("🔍 Save Response JSON: \(json)")
                             if let isLooseDup = json["is_potential_duplicate"] as? Bool, isLooseDup {
                                 print("⚠️ Server flagged as Loose Duplicate!")
                                 updatedData.isPotentialDuplicate = true
                             }
                        }
                        
                        await MainActor.run {
                            self.onSaveSuccess?(updatedData)
                            isSaving = false
                            dismiss()
                        }
                    } else if httpResponse.statusCode == 409 {
                        // Strict Block - Try to get existing ID for resolution
                        let responseJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]
                        let existingId = responseJson?["existingReceiptId"] as? String
                        
                        await MainActor.run {
                            print("⛔️ Strict Duplicate Blocked (409)")
                            self.duplicateReceiptId = existingId
                            isSaving = false
                            self.showingDuplicateAlert = true
                        }
                    } else {
                        // Capture the error body
                        let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown server error"
                        throw NSError(domain: "Network", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server Error \(httpResponse.statusCode): \(errorBody)"])
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

    
    // MARK: - Utilities
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // Helper Formatter
    var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium // e.g. "Dec 18, 2025"
        f.timeStyle = .none
        return f
    }


    
    // MARK: - Isolated Row Component
    struct ReceiptLineItemRow: View {
        @Binding var item: LineItem
        // Callbacks & Data
        let mainCategoryOptions: [String]
        let subCategoryOptionsMap: [String: [String]]
        let onDelete: () -> Void
        let onUpdateCategory: (String, String?, String) -> Void
        
        @Environment(\.colorScheme) var colorScheme
        
        // Colors - Adaptive
        var cardBg: Color { colorScheme == .dark ? Color(hex: "111111") : Color.white }
        var rowBg: Color { colorScheme == .dark ? Color(hex: "0A0A0A") : Color.white }
        var textPrimary: Color { colorScheme == .dark ? Color(hex: "E5E5E5") : Color.black }
        var textSecondary: Color { Color.gray }
        var strokeColor: Color { colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05) }
        
        // Focus State
        enum Field: Hashable {
            case name, price, quantity
        }
        @FocusState private var focusedField: Field?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Row 1: Item Name | Qty | Price | Delete
                HStack(spacing: 8) {
                    // Name
                    TextField("Item Name", text: $item.item)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(colorScheme == .dark ? textPrimary.opacity(0.6) : .black.opacity(0.9))
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .quantity }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            ZStack {
                                cardBg
                                MeshGrid(spacing: 2)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
                            }
                        )
                        .cornerRadius(12)
                        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(strokeColor, lineWidth: 1))
                        .layoutPriority(1)
                    
                    // Quantity (Moved to Row 1)
                    TextField("1", value: $item.quantity, format: .number)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .quantity)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(colorScheme == .dark ? textPrimary.opacity(0.6) : .black.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                cardBg
                                MeshGrid(spacing: 2)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
                            }
                        )
                        .cornerRadius(12)
                        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(strokeColor, lineWidth: 1))
                    
                    // Price
                    HStack(spacing: 2) {
                        Text("£")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? textSecondary.opacity(0.4) : .black.opacity(0.7))
                        TextField("0.00", value: $item.price, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .price)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(colorScheme == .dark ? textPrimary.opacity(0.6) : .black.opacity(0.9))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .frame(width: 85)
                    .background(
                        ZStack {
                            cardBg
                            MeshGrid(spacing: 2)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
                        }
                    )
                    .cornerRadius(12)
                    .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(strokeColor, lineWidth: 1))
                    
                    // Delete Button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(Color.red.opacity(0.8)) // Slightly more visible
                            .frame(width: 32, height: 32)
                            .background(cardBg)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(strokeColor, lineWidth: 1))
                            .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
                
                // Row 2: Main Category | Sub Category
                HStack(spacing: 8) {
                    // Main Category
                    SearchablePicker(
                        title: "Category",
                        placeholder: "Category",
                        selection: Binding(
                            get: { (item.mainCategory ?? "").uppercased() },
                            set: { 
                                item.mainCategory = $0
                                item.subCategory = "" // Reset selection
                            }
                        ),
                        options: mainCategoryOptions.map { $0.uppercased() },
                        allowCreate: true,
                        displayIcon: { CategoryIconMapper.view(for: $0) },
                        onCreate: { _ in },
                        fontSize: 12
                    )
                    .padding(.vertical, 8) // Reduced padding for compact picker
                    .padding(.horizontal, 8)
                    .background(
                        ZStack {
                            cardBg
                            MeshGrid(spacing: 2)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
                        }
                    )
                    .cornerRadius(12) // Match others
                    .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(strokeColor, lineWidth: 1))
                    .frame(maxWidth: .infinity)

                    // Sub Category
                    SearchablePicker(
                        title: "Subcategory",
                        placeholder: "Subcategory",
                        selection: Binding(
                            get: { (item.subCategory ?? "").uppercased() },
                            set: {
                                item.subCategory = $0
                                onUpdateCategory(item.item, item.mainCategory, $0)
                            }
                        ),
                        options: getSubOptions(for: item.mainCategory).map { $0.uppercased() },
                        allowCreate: true,
                        displayIcon: { CategoryIconMapper.view(for: $0) },
                        onCreate: { _ in },
                        fontSize: 12
                    )
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(
                        ZStack {
                            cardBg
                            MeshGrid(spacing: 2)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), lineWidth: 0.5)
                        }
                    )
                    .cornerRadius(12)
                    .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke((item.subCategory ?? "").isEmpty ? Color.yellow.opacity(0.8) : strokeColor, lineWidth: (item.subCategory ?? "").isEmpty ? 1.5 : 1))
                    .frame(maxWidth: .infinity)
                }
            }
//            .padding(12) // Removed inner padding (handled by parent)
//            .background(
//                colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F8F8F8")
//            )
//            .cornerRadius(16)
//            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
//            .overlay(
//                RoundedRectangle(cornerRadius: 16)
//                    .stroke(strokeColor, lineWidth: 1)
//            )
//            .padding(.horizontal, 16)
        }
        
        func getSubOptions(for main: String?) -> [String] {
            guard let main = main, !main.isEmpty else { return [] }
            let key = main.lowercased()
            if let subs = subCategoryOptionsMap[main] { return subs }
            if let subs = subCategoryOptionsMap[key] { return subs }
            return []
        }
    }

    struct DashedLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            return path
        }
    }
}
