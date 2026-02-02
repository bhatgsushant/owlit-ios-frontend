import SwiftUI

struct EditLineItemView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var item: LineItem
    
    // Dropdown Data
    let mainCategoryOptions: [String]
    let subCategoryOptionsMap: [String: [String]]
    let normalizedItemOptions: [String] // New Options for Actual Name
    let onUpdateCategory: (String, String?, String) -> Void // Callback to save preference
    let onUpdateNormalizedName: (String, String) -> Void // Callback to save actual name preference
    
    var onSave: (LineItem) -> Void
    
    // Local Edit State
    @State private var editedItem: LineItem
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name, price, quantity
    }
    
    init(item: Binding<LineItem>, 
         mainCategoryOptions: [String], 
         subCategoryOptionsMap: [String: [String]], 
         normalizedItemOptions: [String] = [], // Default empty
         onUpdateCategory: @escaping (String, String?, String) -> Void,
         onUpdateNormalizedName: @escaping (String, String) -> Void,
         onSave: @escaping (LineItem) -> Void) {
        self._item = item
        self.mainCategoryOptions = mainCategoryOptions
        self.subCategoryOptionsMap = subCategoryOptionsMap
        self.normalizedItemOptions = normalizedItemOptions
        self.onUpdateCategory = onUpdateCategory
        self.onUpdateNormalizedName = onUpdateNormalizedName
        self.onSave = onSave
        self._editedItem = State(initialValue: item.wrappedValue)
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    // Adaptive Colors
    // Adaptive Colors
    private var isDarkMode: Bool { colorScheme == .dark }
    // User Requested: "Creamy White" for Light Mode, "Grey" for Dark Mode Container
    private var containerBg: Color { isDarkMode ? Color(hex: "1C1C1E") : Color(hex: "FDFCFA") }
    private var primaryText: Color { isDarkMode ? Color.white : Color.black }
    private var secondaryText: Color { isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6) }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - Page Level
                ZStack {
                    Color(isDarkMode ? Color(hex: "0A0A0A") : Color(hex: "F2F2F7"))
                    
                    if isDarkMode {
                        MeshGrid(spacing: 4.5)
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    }
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Section 1: Item Details
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Item Details")
                                .font(.custom("FKGroteskTrial-Medium", size: 13))
                                .foregroundColor(isDarkMode ? AppTheme.textSecondary : Color.black.opacity(0.7))
                                .padding(.leading, 4)
                            
                            VStack(spacing: 12) {
                                // Name
                                TextField("Item Name", text: $editedItem.item)
                                    .font(.custom("FKGroteskTrial-Regular", size: 14))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .padding(16)
                                    .withMeshCardStyle(colorScheme: colorScheme)
                                    .focused($focusedField, equals: .name)
                                
                                // Price
                                HStack {
                                    Text("Price")
                                        .font(.custom("FKGroteskTrial-Regular", size: 14))
                                        .foregroundColor(isDarkMode ? AppTheme.textSecondary : Color.black.opacity(0.7))
                                    Spacer()
                                    TextField("0.00", value: $editedItem.price, format: .number.precision(.fractionLength(2)))
                                        .font(.custom("BerkeleyMono-Regular", size: 14))
                                        .foregroundColor(Color(hex: "27A565"))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .focused($focusedField, equals: .price)
                                }
                                .padding(16)
                                .withMeshCardStyle(colorScheme: colorScheme)
                                
                                // Quantity
                                HStack {
                                    Text("Quantity")
                                        .font(.custom("FKGroteskTrial-Regular", size: 14))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                    
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            if (editedItem.quantity ?? 1) > 1 {
                                                editedItem.quantity = (editedItem.quantity ?? 1) - 1
                                            }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                                                .font(.system(size: 18))
                                        }
                                        
                                        TextField("1", value: $editedItem.quantity, format: .number)
                                            .font(.custom("BerkeleyMono-Regular", size: 14))
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.center)
                                            .focused($focusedField, equals: .quantity)
                                            .frame(width: 40)
                                        
                                        Button(action: {
                                            editedItem.quantity = (editedItem.quantity ?? 1) + 1
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(Color(hex: "27A565"))
                                                .font(.system(size: 18))
                                        }
                                    }
                                }
                                .padding(16)
                                .withMeshCardStyle(colorScheme: colorScheme)
                            }
                        }
                        
                        // Section 2: Category
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Category")
                                .font(.custom("FKGroteskTrial-Medium", size: 14))
                                .foregroundColor(isDarkMode ? AppTheme.textSecondary : Color.black.opacity(0.7))
                                .padding(.leading, 4)
                            
                            VStack(spacing: 12) {
                                SearchablePicker(
                                    title: "Category",
                                    placeholder: "Select Category",
                                    selection: Binding(
                                        get: { editedItem.mainCategory ?? "" },
                                        set: { editedItem.mainCategory = $0 }
                                    ),
                                    options: mainCategoryOptions,
                                    allowCreate: true,
                                    displayIcon: { CategoryIconMapper.view(for: $0) },
                                    onCreate: { _ in }
                                )
                                .padding(16)
                                .withMeshCardStyle(colorScheme: colorScheme)
                                
                                SearchablePicker(
                                    title: "Subcategory",
                                    placeholder: "Select Subcategory",
                                    selection: Binding(
                                        get: { editedItem.subCategory ?? "" },
                                        set: { editedItem.subCategory = $0 }
                                    ),
                                    options: getSubOptions(for: editedItem.mainCategory),
                                    allowCreate: true,
                                    displayIcon: { CategoryIconMapper.view(for: $0) },
                                    onCreate: { _ in }
                                )
                                .padding(16)
                                .withMeshCardStyle(colorScheme: colorScheme)
                            }    // Helper for consistency
                        }
                        
                        // Section 3: Actual Name (Normalized)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Actual Name")
                                .font(.custom("FKGroteskTrial-Medium", size: 14))
                                .foregroundColor(isDarkMode ? AppTheme.textSecondary : Color.black.opacity(0.7))
                                .padding(.leading, 4)
                            
                            SearchablePicker(
                                title: "Actual Name",
                                placeholder: "Select Actual Name",
                                selection: Binding(
                                    get: { editedItem.normalizedName ?? "" },
                                    set: { editedItem.normalizedName = $0 }
                                ),
                                options: normalizedItemOptions,
                                allowCreate: true, // Allow user to add new normalized names
                                displayIcon: { _ in AnyView(Image(systemName: "tag.fill").font(.system(size: 12))) },
                                onCreate: { _ in }
                            )
                            .padding(16)
                            .withMeshCardStyle(colorScheme: colorScheme)
                        }
                        
                        // Spacer to push buttons down slightly
                        Color.clear.frame(height: 20)
                        
                        // Bottom Action Buttons (Inside ScrollView)
                        HStack(spacing: 12) {
                            // Cancel (Nevermind Style)
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Cancel")
                                    .font(.custom("FKGroteskTrial-Bold", size: 16))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(colorScheme == .dark ? Color(hex: "292929") : Color(hex: "F7F7F2")) // Creamy White
                                    .cornerRadius(16)
                            }
                            
                            // Save (Primary Style)
                            Button(action: {
                                // Apply changes
                                item = editedItem
                                // If category changed, trigger preference update
                                if let main = editedItem.mainCategory, let sub = editedItem.subCategory, !main.isEmpty, !sub.isEmpty {
                                    onUpdateCategory(editedItem.item, main, sub)
                                }
                                
                                // If actual name changed/set, trigger preference update
                                if let normalized = editedItem.normalizedName, !normalized.isEmpty {
                                    onUpdateNormalizedName(editedItem.item, normalized)
                                }
                                
                                onSave(editedItem)
                                dismiss()
                            }) {
                                Text("Save")
                                    .font(.custom("FKGroteskTrial-Bold", size: 16))
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(colorScheme == .dark ? Color.white : Color.black)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.2), radius: 8, x: 0, y: 4)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        ZStack {
                            containerBg
                            if !isDarkMode {
                                MeshGrid(spacing: 4.5)
                                    .stroke(Color.gray.opacity(0.07), lineWidth: 0.5)
                            }
                        }
                    )
                    .cornerRadius(12)
                    .padding(16)
                }
                
                
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar Removed
            }
        }
    }
    
    // Helper
    func getSubOptions(for main: String?) -> [String] {
        guard let main = main, !main.isEmpty else { return [] }
        let key = main.lowercased()
        if let subs = subCategoryOptionsMap[main] { return subs }
        if let subs = subCategoryOptionsMap[key] { return subs }
        return []
    }
}

extension View {
    func withMeshCardStyle(colorScheme: ColorScheme) -> some View {
        // Opaque background to hide mesh underneath
        let adaptiveCardBg = colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white
        let gridLineColor = colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.02)
        
        return self
            .background(
                ZStack {
                    adaptiveCardBg
                    if colorScheme == .dark {
                        MeshGrid(spacing: 4.5)
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 6, x: 0, y: 3)
    }
}
