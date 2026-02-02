import SwiftUI
import Charts

struct AnalyticsDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // State
    @State private var timeRange: String = "month" // "week", "month", "quarter", "year", "all"
    @State private var data: AnalyticsOverview?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var recentReceipts: [ReceiptData] = [
        ReceiptData(id: "test-1", merchantName: "Test Store", transactionDate: "2025-01-01", totalAmount: 15.50)
    ]
    @State private var receiptToEdit: ReceiptData?
    @State private var showEditSheet = false
    
    // Time Range Options
    let timeRanges = [
        ("Week", "week"),
        ("Month", "month"),
        ("Quarter", "quarter"),
        ("Year", "year")
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        Task { await loadData() }
                    }
                    Spacer()
                } else if !isLoading {
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("Recent Receipts") // Added Title for clarity
                                .font(.custom("FKGroteskTrial-Regular", size: 24))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            
                            // Recent Scanned Receipts (Moved to TOP)
                            RecentReceiptsSection(
                                receipts: recentReceipts, 
                                onEdit: { receipt in self.receiptToEdit = receipt; self.showEditSheet = true },
                                onDelete: { receipt in deleteReceipt(receipt.id) }
                            )
                            
                            if let data = data {
                                // Category Drilldown (Bar Chart)
                                categorySection(data)
                                
                                // Sub-category (Pie Chart - approximated with donut or list if simple)
                                subCategorySection(data)
                                
                                // Timeline Spend (Line Chart)
                                trendSection(data)
                                
                                // Top Merchants (Bar Chart)
                                merchantSection(data)
                                
                                // Top Store Types (Bar Chart)
                                storeTypeSection(data)
                                
                                // Top Items Table
                                itemsButtomSheet(data)
                            } else if recentReceipts.isEmpty {
                                // Show message if EVERYTHING is empty (and receipts also empty)
                                Text("No analytics or receipts found.")
                                    .foregroundColor(.gray)
                                    .padding(.top, 50)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 50) // Extra padding for scrolling
                    }
                }
            }
        }

        .sheet(isPresented: $showEditSheet) {
            if var receipt = receiptToEdit {
                 // Ensure ID is set for update
                 let _ = { receipt.existingReceiptId = receipt.id }()
                 ScanReceiptView(image: UIImage(), data: receipt) { _ in
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
        .onChange(of: timeRange) { _ in
            Task { await loadData() }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back").font(.custom("FKGroteskTrial-Regular", size: 16))
                    }
                    .foregroundColor(Color(hex: "8E8E93"))
                }
                .padding(.leading, 8)
                .padding(.vertical, 8)
                .background(Color(hex: "1C1C1E"))
                .cornerRadius(20)
                
                Spacer()
                
                // Segmented Picker
                HStack(spacing: 0) {
                    ForEach(timeRanges, id: \.1) { (label, value) in
                        Button(action: {
                            timeRange = value
                        }) {
                            Text(label)
                                .font(.custom("FKGroteskTrial-Bold", size: 13))
                                .foregroundColor(timeRange == value ? .white : Color.gray)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    timeRange == value ? Color(hex: "0F3D2E") : Color.clear
                                )
                                .cornerRadius(14)
                        }
                    }
                }
                .padding(4)
                .background(Color(hex: "1C1C1E"))
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Text("Category Drilldown")
                .font(.custom("FKGroteskTrial-Regular", size: 32)) // Changed from serif
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            

            Text("Explore your highest-spend categories.")
                .font(.custom("FKGroteskTrial-Regular", size: 15))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Sections
    
    private func categorySection(_ data: AnalyticsOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            customBarChart(
                title: "Categories",
                items: data.categories.prefix(6).map { ($0.label.uppercased(), $0.value) },
                color: Color(hex: "FFF1F2")
            )
        }
        .padding()
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(16)
    }
    
    private func subCategorySection(_ data: AnalyticsOverview) -> some View {
        // Simple Pie/Donut representation using SectorMark
        VStack(alignment: .leading, spacing: 16) {
             Text("Sub-category Breakdown")
                .font(.custom("FKGroteskTrial-Regular", size: 18))
                .foregroundColor(.white)

             if #available(iOS 17.0, *) {
                 Chart(data.subCategories.prefix(8)) { item in
                     SectorMark(
                         angle: .value("Total", item.value),
                         innerRadius: .ratio(0.6),
                         angularInset: 1.5
                     )
                     .cornerRadius(5)
                     .foregroundStyle(by: .value("Category", item.label.uppercased()))
                 }
                 .frame(height: 250)
                 .chartLegend(position: .bottom, spacing: 20)
                 .chartLegend(.visible)
             } else {
                 // Fallback for older iOS
                 ForEach(data.subCategories.prefix(5)) { item in
                      HStack {
                          Text(item.label.uppercased())
                              .font(.custom("FKGroteskTrial-Regular", size: 14))
                              .foregroundColor(.gray)
                          Spacer()
                          Text(formatCurrency(item.value))
                              .font(.custom("FKGroteskTrial-Regular", size: 14)) // Number font
                              .foregroundColor(.white)
                      }
                 }
             }
        }
        .padding()
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(16)
    }
    
    private func trendSection(_ data: AnalyticsOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline Spend Trend")
                .font(.custom("FKGroteskTrial-Regular", size: 18))
                .foregroundColor(.white)
            
            Chart(data.trend) { point in
                LineMark(
                    x: .value("Date", formatDate(point.date)),
                    y: .value("Amount", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.green)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                AreaMark(
                    x: .value("Date", formatDate(point.date)),
                    y: .value("Amount", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green.opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel() {
                        if let doubleValue = value.as(Double.self) {
                            Text("£\(Int(doubleValue))")
                                .font(.custom("FKGroteskTrial-Regular", size: 10)) // Axis Font
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .chartXAxis {
                 AxisMarks(values: .automatic) { value in
                     AxisValueLabel()
                        .font(.custom("FKGroteskTrial-Regular", size: 10)) // Axis Font
                        .foregroundStyle(Color.gray)
                 }
            }
        }
        .padding()
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(16)
    }
    
    private func merchantSection(_ data: AnalyticsOverview) -> some View {
        customBarChart(
             title: "Top Merchants",
             items: data.merchants.prefix(6).map { ($0.label, $0.value) },
             color: Color.purple
        )
        .padding()
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(16)
    }
    
    private func storeTypeSection(_ data: AnalyticsOverview) -> some View {
        customBarChart(
             title: "Top Store Types",
             items: data.storeTypes.prefix(6).map { ($0.label, $0.value) },
             color: Color.orange
        )
        .padding()
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(16)
    }
    
    private func itemsButtomSheet(_ data: AnalyticsOverview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Breakdown")
                .font(.custom("FKGroteskTrial-Regular", size: 18))
                .foregroundColor(.white)
            
            // Header
            HStack {
                Text("Item")
                    .font(.custom("FKGroteskTrial-Regular", size: 12))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Avg Price")
                    .font(.custom("FKGroteskTrial-Regular", size: 12))
                    .foregroundColor(.gray)
                    .frame(width: 80, alignment: .trailing)
                
                Text("Total")
                    .font(.custom("FKGroteskTrial-Regular", size: 12))
                    .foregroundColor(.gray)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.bottom, 8)
            Divider().background(Color.gray.opacity(0.3))
            
            ForEach(data.items.prefix(10)) { item in
                HStack {
                    Text(item.name.capitalized)
                        .font(.custom("FKGroteskTrial-Regular", size: 14))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatCurrency(item.avgPrice))
                         .font(.custom("FKGroteskTrial-Regular", size: 13)) // Number font
                         .foregroundColor(.gray)
                         .frame(width: 80, alignment: .trailing)
                    
                    Text(formatCurrency(item.total))
                        .font(.custom("FKGroteskTrial-Regular", size: 13)) // Number font
                        .foregroundColor(.white)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.vertical, 6)
                Divider().background(Color.gray.opacity(0.1))
            }
        }
        .padding()
        .background(Color(hex: "1C1C1E"))
        .cornerRadius(16)
    }
    
    // MARK: - Reusable Charts
    
    // A customized horizontal bar chart simulating the provided image style
    private func customBarChart(title: String, items: [(String, Double)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.custom("FKGroteskTrial-Regular", size: 18))
                .foregroundColor(.white)
            
            if items.isEmpty {
                Text("No data available").foregroundColor(.gray).font(.custom("FKGroteskTrial-Regular", size: 12))
            } else {
                Chart {
                    ForEach(items, id: \.0) { item in
                        // Simple Bar (No Background Track)
                        BarMark(
                            x: .value("Amount", item.1),
                            y: .value("Category", item.0)
                        )
                        .foregroundStyle(color)
                        .cornerRadius(6)
                        .annotation(position: .trailing, alignment: .leading) {
                            Text(formatCurrency(item.1))
                                .font(.custom("FKGroteskTrial-Regular", size: 12)) // Number font
                                .foregroundColor(.white)
                                .padding(.leading, 4)
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .foregroundStyle(Color.white)
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                    }
                }
                .frame(height: CGFloat(items.count * 50 + 20))
            }
        }
    }
    
    // MARK: - Data Loading & Aggregation
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        guard let token = authManager.token else { 
            print("❌ No token found in Analytics View")
            isLoading = false
            return 
        }
        
        // 1. Fetch Recent Receipts (Parallel)
        if let token = authManager.token {
            Task {
                do {
                    let receipts = try await APIClient.shared.fetchReceipts(token: token)
                    await MainActor.run {
                        self.recentReceipts = receipts
                    }
                } catch {
                    print("Failed to fetch receipts for dashboard: \(error)")
                }
            }
        }

        // 2. Trigger Manager Refresh (Handles Disk Cache + Network)
        try? await AnalyticsManager.shared.refreshData(token: token)
            
        // 3. Fetch Data from Manager (Single Source of Truth)
        let items = AnalyticsManager.shared.allLineItems
            
        if items.isEmpty {
            // Don't show error immediately, just set data nil so we can still show receipts
            await MainActor.run {
                self.data = nil
                self.isLoading = false
            }
        } else {
            // 4. Process Data
            let processed = await Task.detached(priority: .userInitiated) {
                return self.processLineItems(items, timeRange: self.timeRange)
            }.value
            
            await MainActor.run {
                self.data = processed
                self.isLoading = false
            }
        }
    }
    
    // MARK: - State
    @State private var receiptIdToDelete: String?
    @State private var showDeleteAlert = false

    private func deleteReceipt(_ id: String?) {
        guard let id = id else { return }
        self.receiptIdToDelete = id
        self.showDeleteAlert = true
    }

    private func performDelete(id: String) {
        guard let token = authManager.token else { return }
        Task {
            do {
                try await APIClient.shared.deleteReceipt(receiptId: id, token: token)
                // Remove locally
                await MainActor.run {
                    self.recentReceipts.removeAll { $0.id == id }
                }
            } catch {
                print("Failed to delete receipt: \(error)")
            }
        }
    }
    
    private func processLineItems(_ items: [LineItem], timeRange: String) -> AnalyticsOverview {
        let calendar = Calendar.current
        let now = Date()
        
        // 1. Filter by Date AND valid Price
        let filteredItems = items.filter { item in
            let price = item.totalPrice ?? ((item.price ?? 0) * Double(item.quantity ?? 1))
            guard price > 0 else { return false }
            
            guard let dateStr = item.transactionDate,
                  let date = parseDate(dateStr) else { return false }
            
            switch timeRange {
            case "week":
                let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                return date >= startOfWeek
            case "month":
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                return date >= startOfMonth
            case "quarter":
                let month = calendar.component(.month, from: now)
                let startMonth = ((month - 1) / 3) * 3 + 1
                let startOfQuarter = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: startMonth, day: 1))!
                return date >= startOfQuarter
            case "year":
                let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
                return date >= startOfYear
            default: // "all"
                return true
            }
        }
        
        // 2. Aggregate
        var catMap: [String: Double] = [:]
        var subCatMap: [String: Double] = [:]
        var merchantMap: [String: Double] = [:] // LineItem doesn't always have merchantName unless we encoded it? 
        // Note: The /api/analytics/line-items query returns merchant_name. 
        // But the LineItem struct definition needs to support decoding merchant_name if it didn't already.
        // Checking LineItem struct... it does NOT have merchantName. 
        // WAIT: I need to update LineItem to parse 'merchant_name' from the flat row if I want to aggregate merchants here.
        // For now, I'll assume I can't do merchant aggregation properly without updating LineItem struct again.
        // User asked for "Detailed Breakdown chart... replace item with normalized_name".
        // To properly support the FULL dashboard (Merchants, Store Types), I need merchant_name and store_type in LineItem.
        // I will assume for now I will rely on what I have, but to be robust I should probably have updated LineItem struct.
        // Let's check LineItem struct one more time in my mind... 
        // It has `mainCategory`, `subCategory`, `item`, `price`... no merchantName.
        // This is a problem for "Top Merchants".
        // HOWEVER, I can't update LineItem struct inside this tool call.
        // I will proceed with Item aggregation modification as requested, and note that Merchant/Store charts might be empty if I rely purely on LineItem.
        // actually, looking at the previous code, `processReceipts` iterated Receipts which had `merchantName`.
        // Now I have flat items. If `LineItem` doesn't have `merchantName`, I lose that data.
        // I MUST UPDATE LineItem struct first to support `merchant_name`.
        
        // RE-PLAN: I'll finish this "replace" but I need to update LineItem struct to include `merchantName` and `storeType`. 
        // I'll update the Aggregation Logic assuming those fields will exist.
        
        var storeMap: [String: Double] = [:]
        var itemMap: [String: (total: Double, count: Int, priceSum: Double)] = [:]
        var trendMap: [String: Double] = [:] 
        
        for item in filteredItems {
             let price = item.totalPrice ?? ((item.price ?? 0) * Double(item.quantity ?? 1))
             
             // Categories
             let main = (item.mainCategory ?? "Uncategorized").capitalized
             let sub = (item.subCategory ?? "Other").capitalized
             catMap[main, default: 0] += price
             subCatMap[sub, default: 0] += price
             
             // Merchant
             // Use item.merchantName if available.
             let merchant = (item.merchantName ?? "Unknown").trimmingCharacters(in: .whitespacesAndNewlines)
             if !merchant.isEmpty {
                 merchantMap[merchant, default: 0] += price
             }

             // Store Type
             let store = (item.storeType ?? "Other").capitalized
             storeMap[store, default: 0] += price
             
             // Items (Normalized)
             let itemName = (item.normalizedName ?? item.item).capitalized
             var current = itemMap[itemName] ?? (0, 0, 0)
             current.total += price
             current.count += (item.quantity ?? 1)
             itemMap[itemName] = current
             
             // Trend is now handled separately via AnalyticsManager.shared.computeMonthlyTrend()
         }
         
        // 3. Convert Maps to Sorted Arrays
        let categories = catMap.map { AnalyticsCategory(label: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
        
        let subCategories = subCatMap.map { AnalyticsCategory(label: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
        
        let merchants = merchantMap.map { AnalyticsCategory(label: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
        
        let storeTypes = storeMap.map { AnalyticsCategory(label: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
            
        let itemsArr = itemMap.map { (key, value) -> AnalyticsItem in
            AnalyticsItem(
                name: key,
                total: value.total,
                count: value.count,
                avgPrice: value.count > 0 ? value.total / Double(value.count) : 0
            )
        }.sorted { $0.total > $1.total }
        
         let trend = AnalyticsManager.shared.computeMonthlyTrend(months: 6)
            
        return AnalyticsOverview(
            categories: categories,
            subCategories: subCategories,
            trend: trend,
            merchants: merchants,
            storeTypes: storeTypes,
            items: itemsArr
        )
    }
    
    private func parseDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: str)
    }
    
    // Grouping key for trend 
    private func formatDateForTrend(_ date: Date, range: String) -> String {
        let formatter = DateFormatter()
        if range == "year" || range == "all" {
            formatter.dateFormat = "yyyy-MM" // Resize to Month
        } else {
            formatter.dateFormat = "yyyy-MM-dd" // Daily
        }
        return formatter.string(from: date)
    }
    
    // MARK: - Formatters
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "£0.00"
    }
    
    private func formatDate(_ isoString: String) -> String {
        // Since we are now doing client-side aggregation, the "date" in AnalyticsTrend is already formatted by formatDateForTrend (YYYY-MM-DD or YYYY-MM)
        // We just need to parse it back and display nicely.
        let formatter = DateFormatter()
        formatter.dateFormat = isoString.count == 7 ? "yyyy-MM" : "yyyy-MM-dd"
        
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = isoString.count == 7 ? "MMM yyyy" : "MMM d"
            return displayFormatter.string(from: date)
        }
        return isoString
    }

}

// Preview
#Preview {
    AnalyticsDashboardView()
        .environmentObject(AuthManager())
}
