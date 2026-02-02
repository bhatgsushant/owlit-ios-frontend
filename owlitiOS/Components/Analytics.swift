import SwiftUI
import Charts
import Foundation
import UIKit

struct Analytics: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authManager: AuthManager
    // Navigation Callbacks
    var onMenuTap: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    // MARK: - State
    @State private var timeRange: String = "month" // "week", "month", "quarter", "year"
    @State private var viewMode: String = "value" // "value", "percent"
    @State private var drillLevel: DrillLevel = .main
    @State private var selectedCategory: String? = nil
    @State private var selectedSubCategory: String? = nil
    
    // New UX State
    @State private var isExpanded = false
    @State private var sortOrder: SortOrder = .top
    
    enum SortOrder { case top, bottom }
    
    @State private var allLineItems: [LineItem] = []
    @State private var itemsWithDates: [(item: LineItem, date: Date)] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @State private var startAnimation = false
    @State private var filteredEntries: [ChartEntry] = []
    @State private var monthlyTrend: [MonthlyTrend] = []
    @State private var selectedTrendPoint: MonthlyTrend? = nil // Interaction State
    @State private var isTrendBarChart = false
    @State private var tooltipX: CGFloat = 0
    @State private var merchantBubbles: [BubbleData] = []
    @State private var dynamicBubbleHeight: CGFloat = 340 // Dynamic height state
    
    // Recent Receipts State
    @State private var recentReceipts: [ReceiptData] = []
    @State private var receiptToEdit: ReceiptData?
    @State private var showEditSheet = false
    @State private var receiptIdToDelete: String?
    @State private var showDeleteAlert = false
    
    struct MonthlyTrend: Identifiable {
        var id: Date { date } // Stable ID for animation
        let date: Date
        let amount: Double
        let label: String
    }
    
    // MARK: - Enums
    enum DrillLevel {
        case main, sub, item
    }
    
    // MARK: - Constants
    let timeRanges = [
        ("7D", "week"),
        ("Month", "month"),
        ("Quarter", "quarter"),
        ("Year", "year"),
        ("ALL", "all")
    ]
    
    let palette: [Color] = [
        Color(hex: "6366F1"), // Indigo
        Color(hex: "EC4899"), // Pink
        Color(hex: "F97316"), // Orange
        Color(hex: "22D3EE"), // Cyan
        Color(hex: "10B981"), // Emerald
        Color(hex: "FBBF24"), // Amber
        Color(hex: "8B5CF6"), // Violet
        Color(hex: "EF4444"), // Red
        Color(hex: "14B8A6"), // Teal
        Color(hex: "A855F7")  // Purple
    ]

    // MARK: - Computed Colors
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white }
    private var tooltipBg: Color { colorScheme == .dark ? Color(hex: "2C2C2E").opacity(0.95) : Color.white.opacity(0.95) }
    private var primaryText: Color { colorScheme == .dark ? .white : .black }
    private var secondaryText: Color { colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6) }
    private var accentGreen: Color { Color(hex: "10B981") }
    private var accentOrange: Color { Color(hex: "FB923C") } // Orangish Yellow (Orange-400/500 mix)
    private var gridColor: Color { colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.02) }
    private var dividerTint: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1) }

    var body: some View {
        ZStack {
            cardBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Nav Bar
                HStack {
                     // Hamburger Removed
                     Spacer()
                    
                    Button(action: { 
                        triggerHaptic(style: .medium)
                        if let onClose = onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(primaryText.opacity(0.7))
                            .padding(8)
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16) // Safe Area padding
                .padding(.bottom, 8)

                // MARK: - Header
                headerSection
                    .padding(.top, 0)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(accentGreen)
                        .scaleEffect(1.5)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.custom("FKGroteskTrial-Medium", size: 16))
                            .foregroundColor(primaryText)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadInitialData() }
                        }
                        .padding()
                        .background(accentGreen.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(40)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // MARK: - Monthly Spend Trend
                            monthlyTrendCard
                            
                            // MARK: - Category Drilldown Card
                            categoryDrilldownCard
                            
                            // MARK: - Store Bubble Chart
                            storeBubbleCard
                            
                            // MARK: - Recent Receipts
                            recentReceiptsCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if var receipt = receiptToEdit {
                 // Ensure ID is set for update
                 let _ = { receipt.existingReceiptId = receipt.id }()
                 ScanReceiptView(image: UIImage(), data: receipt, saveMode: .server) { _ in
                     // Reload data on save
                     Task { await loadInitialData() }
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
            await loadInitialData()
        }
        .onChange(of: timeRange) { _ in updateChartData() }
        .onChange(of: drillLevel) { _ in updateChartData() }
        .onChange(of: allLineItems.count) { _ in updateChartData() }
        .onChange(of: selectedTrendPoint?.id) { _ in
            if selectedTrendPoint != nil {
                triggerHaptic(style: .light)
            }
        }
    }
    
    // MARK: - Helpers
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
    
    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 0) {
            // Title Removed completely
            
            Spacer()
            
            // Time Range Picker
            timeRangePicker
        }
        .padding(.horizontal, 20) // Keep padding for safe area alignment
    }
    
    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(timeRanges, id: \.1) { (label, value) in
                Button(action: {
                    triggerHaptic(style: .light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        timeRange = value
                    }
                }) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(timeRange == value ? (colorScheme == .dark ? .white : Color(hex: "3A3F4C")) : (colorScheme == .dark ? .white.opacity(0.4) : Color.black.opacity(0.3)))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            ZStack {
                                if timeRange == value {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(colorScheme == .dark ? Color(hex: "3A3F4C") : .white)
                                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15), radius: 4, x: 0, y: 2)
                                        .matchedGeometryEffect(id: "timeRange", in: animationNamespace)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(dividerTint, lineWidth: 1))
        )
    }

    @Namespace private var animationNamespace

    // MARK: - Category Drilldown Card
    private var categoryDrilldownCard: some View {
        VStack(spacing: 20) {
            // Controls (Back, All Categories, Toggle)
            VStack(spacing: 12) {
                // Row 1: Navigation
                HStack {
                    if drillLevel != .main {
                        Button(action: goBack) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(primaryText)
                                .padding(10)
                                .background(cardBg.opacity(0.5))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(dividerTint, lineWidth: 1))
                        }
                    }
                    
                    Text(currentDrillTitle)
                        .font(.custom("FKGroteskTrial-Medium", size: 14))
                        .foregroundColor(primaryText)
                        
                    Spacer()
                }
                
                // Row 2: Controls
                HStack(spacing: 8) {
                    Spacer()
                    
                    // Toggle Mode
                    HStack(spacing: 0) {
                        ForEach(["value", "percent"], id: \.self) { mode in
                            Button(action: {
                                triggerHaptic(style: .light)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    viewMode = mode
                                }
                            }) {
                                Text(mode == "value" ? "£ Value" : "% Share")
                                    .font(.custom("FKGroteskTrial-Medium", size: 11))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        ZStack {
                                            if viewMode == mode {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(primaryText.opacity(colorScheme == .dark ? 0.12 : 0.06))
                                                    .matchedGeometryEffect(id: "viewMode", in: animationNamespace)
                                            }
                                        }
                                    )
                                    .foregroundColor(viewMode == mode ? primaryText : secondaryText)
                            }
                        }
                    }
                    .background(cardBg.opacity(0.5))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(dividerTint, lineWidth: 1))
                    
                    // Sort Toggle
                    HStack(spacing: 0) {
                        ForEach([SortOrder.top, SortOrder.bottom], id: \.self) { order in
                            Button(action: {
                                triggerHaptic(style: .light)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    sortOrder = order
                                    updateChartData()
                                }
                            }) {
                                Text(order == .top ? "Top" : "Btm")
                                    .font(.custom("FKGroteskTrial-Medium", size: 11))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        ZStack {
                                            if sortOrder == order {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(primaryText.opacity(colorScheme == .dark ? 0.12 : 0.06))
                                                    .matchedGeometryEffect(id: "sortOrder", in: animationNamespace)
                                            }
                                        }
                                    )
                                    .foregroundColor(sortOrder == order ? primaryText : secondaryText)
                            }
                        }
                    }
                    .background(cardBg.opacity(0.5))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(dividerTint, lineWidth: 1))
                }
            }
            
            // The Chart
            chartContainer
            
            // Expand/Collapse Button
            if !filteredEntries.isEmpty {
                Button(action: {
                    triggerHaptic(style: .light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(secondaryText)
                        .padding(8)
                        .background(primaryText.opacity(0.05))
                        .clipShape(Circle())
                }
                .padding(.top, -8)
            }
        }
        .padding(20)
        .background(
            ZStack {
                cardBg
                MeshGrid(spacing: 5)
                    .stroke(gridColor, lineWidth: 0.5)
            }
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 10, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
    }
    
    // MARK: - Store Bubble Card
    private var storeBubbleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Stores")
                .font(.custom("FKGroteskTrial-Medium", size: 13))
                .foregroundColor(primaryText)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            if merchantBubbles.isEmpty {
                Text("No data available")
                    .font(.custom("FKGroteskTrial-Regular", size: 14))
                    .foregroundColor(secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
            } else {
                StoreBubbleChart(bubbles: merchantBubbles)
                    .frame(height: dynamicBubbleHeight) // Use dynamic height
            }
        }
        .background(
            ZStack {
                cardBg
                MeshGrid(spacing: 5)
                    .stroke(gridColor, lineWidth: 0.5)
            }
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 10, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
    }
    
    private var chartContainer: some View {
        let entries = isExpanded ? filteredEntries : Array(filteredEntries.prefix(5))
        
        return VStack {
            if entries.isEmpty {
                Text("No data for this period")
                    .font(.custom("FKGroteskTrial-Regular", size: 14))
                    .foregroundColor(secondaryText)
                    .frame(height: 200)
            } else {
                Chart {
                    let maxVal = entries.map { viewMode == "value" ? $0.value : $0.percent }.max() ?? 1.0
                    
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        let amount = viewMode == "value" ? entry.value : entry.percent
                        let label = entry.label
                        
                        // Calculate intensity (0.4 to 1.0) based on relative value
                        let intensity = maxVal > 0 ? (amount / maxVal) : 1.0
                        let opacity = 0.4 + (intensity * 0.6)
                        
                        BarMark(
                            x: .value("Amount", amount),
                            y: .value("Category", label)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.yellow.opacity(opacity * 0.8),
                                    Color.yellow.opacity(opacity)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(4) // Sharper, more premium corner
                        .annotation(position: .trailing, alignment: .leading) {
                            chartBarAnnotation(entry: entry)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic) { value in
                        AxisValueLabel() {
                            if let name = value.as(String.self) {
                                Text(name)
                                    .font(.custom("FKGroteskTrial-Medium", size: 12))
                                    .foregroundColor(primaryText)
                            }
                        }
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(max(5, entries.count) * 52 + 40))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: entries.count)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                handleChartTap(at: location, proxy: proxy, geo: geo)
                            }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func chartBarAnnotation(entry: ChartEntry) -> some View {
        let text = viewMode == "value" ? formatCurrency(entry.value) : String(format: "%.1f%%", entry.percent)
        Text(text)
            .font(.custom("FKGroteskTrial-Medium", size: 12))
            .foregroundColor(primaryText)
            .padding(.leading, 6)
    }
    
    private var currentDrillTitle: String {
        switch drillLevel {
        case .main: return "All Categories"
        case .sub: return selectedCategory ?? "Sub-categories"
        case .item: return selectedSubCategory ?? "Items"
        }
    }
    
    private func updateChartData() {
        // Run aggregation in a separate task to avoid UI hang
        let currentItemsWithDates = self.itemsWithDates
        let currentDrillLevel = self.drillLevel
        let currentSelectedCategory = self.selectedCategory
        let currentSelectedSubCategory = self.selectedSubCategory
        
        Task {
            // Unified Parallel Calculation
            let (chartData, bubbleData) = (try? await Task.detached(priority: .userInitiated) { [currentItemsWithDates, currentDrillLevel, currentSelectedCategory, currentSelectedSubCategory, timeRangeCopy = self.timeRange] () -> ([ChartEntry], [BubbleData]) in
                 
                 // 1. Common Filtering
                 let calendar = Calendar.current
                 let now = Date()
                 let filteredItems = currentItemsWithDates.filter { (_, date) in
                     switch timeRangeCopy {
                     case "week":
                         let start = calendar.date(byAdding: .day, value: -7, to: now)!
                         return date >= start
                     case "month":
                         let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                         return date >= start
                     case "quarter":
                         let month = calendar.component(.month, from: now)
                         let startMonth = ((month - 1) / 3) * 3 + 1
                         let start = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: startMonth, day: 1))!
                         return date >= start
                     case "year":
                         let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
                         return date >= start
                     default:
                         return true
                     }
                 }
                 
                 // 2. Chart Data Logic
                 var tempEntries: [ChartEntry] = []
                 switch currentDrillLevel {
                 case .main:
                     var map: [String: Double] = [:]
                     for (item, _) in filteredItems {
                         map[item.mainCategory ?? "Other", default: 0] += (item.totalPrice ?? 0)
                     }
                     let total = map.values.reduce(0, +)
                     tempEntries = map.map { ChartEntry(label: $0.key.capitalized, value: $0.value, percent: total > 0 ? ($0.value / total) * 100 : 0) }
                         .sorted { $0.value > $1.value }
                         .prefix(10).map { $0 }
                     
                 case .sub:
                     if let cat = currentSelectedCategory {
                         var map: [String: Double] = [:]
                         for (item, _) in filteredItems where (item.mainCategory ?? "").localizedCaseInsensitiveCompare(cat) == .orderedSame {
                             map[item.subCategory ?? "Other", default: 0] += (item.totalPrice ?? 0)
                         }
                         let total = map.values.reduce(0, +)
                         tempEntries = map.map { ChartEntry(label: $0.key.capitalized, value: $0.value, percent: total > 0 ? ($0.value / total) * 100 : 0) }
                             .sorted { $0.value > $1.value }
                             .prefix(10).map { $0 }
                     }
                 case .item:
                     if let sub = currentSelectedSubCategory {
                         var map: [String: Double] = [:]
                         for (item, _) in filteredItems where (item.subCategory ?? "").localizedCaseInsensitiveCompare(sub) == .orderedSame {
                             map[item.normalizedName ?? item.item, default: 0] += (item.totalPrice ?? 0)
                         }
                         let total = map.values.reduce(0, +)
                         tempEntries = map.map { ChartEntry(label: $0.key.capitalized, value: $0.value, percent: total > 0 ? ($0.value / total) * 100 : 0) }
                             .sorted { $0.value > $1.value }
                             .prefix(10).map { $0 }
                     }
                 }
                 
                 // 3. Bubble Data Logic
                 var merchantMap: [String: Double] = [:]
                  for (item, _) in filteredItems {
                      if let rawName = item.merchantName {
                          let mName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                          if !mName.isEmpty {
                              merchantMap[mName, default: 0] += (item.totalPrice ?? 0)
                          }
                      }
                  }
                 
                 let topMerchants = merchantMap.sorted { $0.value > $1.value }.prefix(10)
                 var bubbleInputs: [(name: String, value: Double, color: Color, domain: String?)] = []
                 
                 let colors: [Color] = [
                    Color(hex: "6366F1"), Color(hex: "EC4899"), Color(hex: "F97316"),
                    Color(hex: "22D3EE"), Color(hex: "10B981"), Color(hex: "FBBF24"),
                    Color(hex: "8B5CF6"), Color(hex: "EF4444"), Color(hex: "14B8A6")
                 ]
                 
                 var colorIndex = 0
                 for (name, val) in topMerchants {
                     // Look up domain
                     let domain = AnalyticsManager.shared.getDomain(for: name)

                     bubbleInputs.append((name: name, value: val, color: colors[colorIndex % colors.count], domain: domain))
                     colorIndex += 1
                 }
                 

                 
                 // Pass a much larger container height to allow free packing without skipping
                 let bubbles = BubbleLayoutEngine.calculateLayout(for: bubbleInputs, containerSize: CGSize(width: 340, height: 1200))
                 
                 return (tempEntries, bubbles)
                 
             }.value) ?? ([], [])
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    // Update Chart
                    if self.sortOrder == .bottom {
                        self.filteredEntries = chartData.sorted { $0.value < $1.value }
                    } else {
                        self.filteredEntries = chartData 
                    }
                    
                    // Update Bubbles
                    self.merchantBubbles = bubbleData
                    
                    // Calculate required height based on bubble extent
                    if !bubbleData.isEmpty {
                        // Find the max Y extent from center (0,0)
                        let maxExtent = bubbleData.map { abs($0.offset.height) + ($0.size / 2) }.max() ?? 150
                        // Total height = (maxExtent * 2) + Header/Footer Padding (~60-80)
                        // We clamp to min 340 to avoid too small charts
                        let calculatedHeight = max(340, (maxExtent * 2) + 80)
                        self.dynamicBubbleHeight = calculatedHeight
                    } else {
                        self.dynamicBubbleHeight = 340
                    }
                }
            }
        }
    }
    
    private func filterItemsByPreParsedDates(_ items: [(item: LineItem, date: Date)]) -> [(item: LineItem, date: Date)] {
        let calendar = Calendar.current
        let now = Date()
        
        return items.filter { (_, date) in
            switch timeRange {
            case "week":
                // Rolling 7-day window
                let startOfPeriod = calendar.date(byAdding: .day, value: -7, to: now)!
                return date >= startOfPeriod
            case "month":
                // Calendar MTD Window
                let startOfOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                return date >= startOfOfMonth
            case "quarter":
                // Calendar QTD Window
                let month = calendar.component(.month, from: now)
                let startMonth = ((month - 1) / 3) * 3 + 1
                let startOfQuarter = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: startMonth, day: 1))!
                return date >= startOfQuarter
            case "year":
                // Keeping strict calendar year for "This Year"
                let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
                return date >= startOfYear
            default:
                return true
            }
        }
    }
    
    struct ChartEntry: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let percent: Double
    }
    
    private func sortAndFormat(_ map: [String: Double]) -> [ChartEntry] {
        let total = map.values.reduce(0, +)
        return map.map { ChartEntry(label: $0.key.capitalized, value: $0.value, percent: total > 0 ? ($0.value / total) * 100 : 0) }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0 }
    }
    
    private func filterItemsByTimeRange(_ items: [LineItem]) -> [LineItem] {
        let calendar = Calendar.current
        let now = Date()
        
        return items.filter { item in
            guard let dateStr = item.transactionDate, let date = parseDate(dateStr) else { return false }
            
            switch timeRange {
            case "week":
                // Rolling 7-day window
                let startOfPeriod = calendar.date(byAdding: .day, value: -7, to: now)!
                return date >= startOfPeriod
            case "month":
                // Calendar MTD Window
                let startOfOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                return date >= startOfOfMonth
            case "quarter":
                // Calendar QTD Window
                let month = calendar.component(.month, from: now)
                let startMonth = ((month - 1) / 3) * 3 + 1
                let startOfQuarter = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: startMonth, day: 1))!
                return date >= startOfQuarter
            case "year":
                // Keeping strict calendar year for "This Year"
                let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
                return date >= startOfYear
            default:
                return true
            }
        }
    }

    private func handleChartTap(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        // Use ChartProxy for precise item detection
        guard let name: String = proxy.value(atY: location.y) else { return }
        guard let entry = filteredEntries.first(where: { $0.label == name }) else { return }
        
        triggerHaptic(style: .light)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if drillLevel == .main {
                selectedCategory = entry.label
                drillLevel = .sub
            } else if drillLevel == .sub {
                selectedSubCategory = entry.label
                drillLevel = .item
            }
        }
    }
    
    private func goBack() {
        triggerHaptic(style: .medium)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if drillLevel == .item {
                drillLevel = .sub
                selectedSubCategory = nil
            } else if drillLevel == .sub {
                drillLevel = .main
                selectedCategory = nil
            }
        }
    }

    private func loadInitialData() async {
        guard let token = authManager.token else {
            print("❌ [Analytics] Load skipped: Auth token is nil")
            self.errorMessage = "Session expired. Please log in again."
            self.isLoading = false
            return
        }
        print("📊 [Analytics] Starting data load from Enriched View (Source of Truth)...")
        isLoading = true
        
        do {
            // 1. Refresh global data (including domains) via Manager
            try await AnalyticsManager.shared.refreshData(token: token)
            
            // 1b. Fetch Recent Receipts (Parallel)
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
            
            // 2. Use the items from the manager
            let items = AnalyticsManager.shared.allLineItems
            print("📊 [Analytics] Successfully fetched \(items.count) line items.")
            
            let calendar = Calendar.current
            var itemsWD: [(item: LineItem, date: Date)] = []
            
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM yy"
            
            for item in items {
                if let dStr = item.transactionDate, let date = parseDate(dStr) {
                    itemsWD.append((item, date))
                }
            }
            
            // NEW: Fixed 6-Month Trend with Zero Padding
            var trendPoints: [MonthlyTrend] = []
            let now = Date()
            
            // 1. Initialize last 6 months with 0.0
            for i in (0..<6).reversed() {
                if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                    let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
                    trendPoints.append(MonthlyTrend(date: startOfMonth, amount: 0, label: monthFormatter.string(from: startOfMonth)))
                }
            }
            
            // 2. Fill with actual data
            for (item, date) in itemsWD {
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
                if let index = trendPoints.firstIndex(where: { $0.date == startOfMonth }) {
                    let currentAmount = trendPoints[index].amount
                    trendPoints[index] = MonthlyTrend(
                        date: startOfMonth, 
                        amount: currentAmount + (item.totalPrice ?? 0),
                        label: trendPoints[index].label
                    )
                }
            }
            
            // 3. Trim leading zeros (keep the window clean if first months are empty)
            while trendPoints.count > 1 && trendPoints.first?.amount == 0 {
                trendPoints.removeFirst()
            }
            
            print("📊 [Analytics] Generated trend with \(trendPoints.count) points (leading zeros trimmed).")
            
            await MainActor.run {
                self.allLineItems = items
                self.itemsWithDates = itemsWD
                self.monthlyTrend = trendPoints
                self.isLoading = false
                self.updateChartData()
                
                withAnimation(.easeOut(duration: 0.8)) {
                    self.startAnimation = true
                }
            }
        } catch {
            print("❌ [Analytics] Load failed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private var monthlyTrendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Monthly Spend Trend")
                    .font(.custom("FKGroteskTrial-Medium", size: 13))
                    .foregroundColor(primaryText)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isTrendBarChart.toggle()
                        triggerHaptic(style: .light)
                    }
                }) {
                    Image(systemName: isTrendBarChart ? "chart.line.uptrend.xyaxis" : "chart.bar.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(primaryText)
                        .padding(8)
                        .background(cardBg.opacity(0.5))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(dividerTint, lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // The Chart
            trendChartContainer
        }
        .background(
            ZStack {
                cardBg
                MeshGrid(spacing: 5)
                    .stroke(gridColor, lineWidth: 0.5)
            }
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 10, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
    }
    
    // MARK: - Recent Receipts Card
    private var recentReceiptsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Receipts")
                .font(.custom("FKGroteskTrial-Medium", size: 13))
                .foregroundColor(primaryText)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            RecentReceiptsSection(
                receipts: recentReceipts, 
                onEdit: { receipt in self.receiptToEdit = receipt; self.showEditSheet = true },
                onDelete: { receipt in deleteReceipt(receipt.id) }
            )
        }
        .background(
            ZStack {
                cardBg
                MeshGrid(spacing: 5)
                    .stroke(gridColor, lineWidth: 0.5)
            }
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 10, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
    }

    // MARK: - Trend Chart Container
    private var trendChartContainer: some View {
        Group {
            if monthlyTrend.isEmpty {
                Text("Not enough data for trend")
                    .font(.custom("FKGroteskTrial-Regular", size: 14))
                    .foregroundColor(secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 270) // Unified height
            } else {
                let currentTrendData = monthlyTrend
                let values = currentTrendData.map { $0.amount }
                let averageSpend = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
                let maxTrendValue = values.max() ?? 100.0
                
                ZStack(alignment: .top) {
                  Chart {
                        ForEach(monthlyTrend) { point in
                            let isAboveAverage = point.amount > (averageSpend + 0.01)
                            let barColor = isAboveAverage ? Color.red : Color.emerald

                            if isTrendBarChart {
                                BarMark(
                                    x: .value("Month", point.date, unit: .month),
                                    y: .value("Expense", point.amount),
                                    width: .ratio(0.8)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [barColor.opacity(0.8), barColor.opacity(0.4)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(4)
                            } else {
                                AreaMark(
                                    x: .value("Month", point.date),
                                    y: .value("Expense", point.amount)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [barColor.opacity(0.2), barColor.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                                
                                LineMark(
                                    x: .value("Month", point.date),
                                    y: .value("Expense", point.amount)
                                )
                                .foregroundStyle(barColor)
                                .interpolationMethod(.catmullRom)
                                .symbol {
                                    Circle()
                                        .fill(barColor)
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                      
                        // Selection Marker (Line Only)
                        if let selected = selectedTrendPoint {
                            RuleMark(x: .value("Date", selected.date))
                                .foregroundStyle(primaryText.opacity(0.1))
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month, count: 1)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date, format: .dateTime.month(.abbreviated))
                                        .font(.custom("FKGroteskTrial-Regular", size: 9))
                                        .foregroundColor(secondaryText)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(dash: [2, 4])).foregroundStyle(gridColor)
                            if let val = value.as(Double.self) {
                                AxisValueLabel {
                                    Text("£\(Int(val))")
                                        .font(.custom("FKGroteskTrial-Regular", size: 10))
                                        .foregroundColor(secondaryText)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...(maxTrendValue * 1.3)) 
                    .frame(height: 270)
                  .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                let calendar = Calendar.current
                                                
                                                // Find the closest month point by distance
                                                let targetMonth = calendar.component(.month, from: date)
                                                let targetYear = calendar.component(.year, from: date)
                                                
                                                if let point = monthlyTrend.min(by: { p1, p2 in
                                                    abs(p1.date.timeIntervalSince(date)) < abs(p2.date.timeIntervalSince(date))
                                                }) {
                                                    selectedTrendPoint = point
                                                    // Store the x-position for tooltip alignment
                                                    if let xPos = proxy.position(forX: point.date) {
                                                        self.tooltipX = xPos + geo[proxy.plotAreaFrame].origin.x
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            selectedTrendPoint = nil
                                        }
                                )
                        }
                    }
                    
                    // Floating Tooltip (Independent of Chart Layout)
                    if let selected = selectedTrendPoint {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "£%.2f", selected.amount))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(primaryText)
                            Text(selected.label)
                                .font(.custom("FKGroteskTrial-Medium", size: 12))
                                .foregroundColor(secondaryText)
                        }
                        .padding(8)
                        .background(tooltipBg) 
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                        .position(x: max(60, min(280, tooltipX)), y: 40)
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    
    // Match web app's formatCategoryLabel logic
    private func formatCategoryLabel(_ value: String?) -> String {
        guard let val = value, !val.isEmpty else { return "Other" }
        // Replace underscores/dashes with spaces
        let cleaned = val.replacingOccurrences(of: "[_-]+", with: " ", options: .regularExpression)
        // Capitalize each word (equivalent to web's map/capitalize logic)
        return cleaned.capitalized
    }
    
    private func parseDate(_ str: String) -> Date? {
        // Try multiple ISO8601 formats
        let formatters = [
            ISO8601DateFormatter(), // Full ISO with time
            {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withFullDate]
                return f
            }(),
            {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withInternetDateTime, .withFractionalSeconds]
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: str) {
                return date
            }
        }
        
        // Final fallback for simple YYYY-MM-DD
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        return simpleFormatter.date(from: str)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "£0.00"
    }

    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

#Preview {
    Analytics().environmentObject(AuthManager())
}

// MARK: - Store Bubble Components

struct BubbleData: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let value: Double
    var color: SwiftUI.Color
    var offset: CGSize = .zero
    var size: CGFloat = 0.0
    var domain: String? = nil
}

struct MerchantDrilldown: Identifiable {
    let id = UUID()
    let name: String
}

struct StoreBubbleChart: View {
    let bubbles: [BubbleData]
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedBubbleID: UUID?
    
    // Detailed Stats State
    @State private var detailedSummary: MerchantSummary?
    @State private var showDetail = false
    
    // Drilldown State
    @State private var drilldownTarget: MerchantDrilldown?
    
    // Config
    let baseSize: CGFloat = 60
    let scaleFactor: CGFloat = 1.2
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            ZStack {
                // Dim background if something is selected - Improved for Light Mode
                if selectedBubbleID != nil {
                     Color(colorScheme == .dark ? .black : .white).opacity(0.1)
                         .ignoresSafeArea()
                         .onTapGesture {
                             withAnimation { selectedBubbleID = nil }
                         }
                }
                
                ForEach(bubbles) { bubble in
                    let isSelected = selectedBubbleID == bubble.id
                    
                    BubbleView(bubble: bubble, isSelected: isSelected)
                        .position(
                            x: center.x + bubble.offset.width,
                            y: center.y + bubble.offset.height
                        )
                        .scaleEffect(isSelected ? 1.2 : 1.0)
                        .zIndex(isSelected ? 100 : 1)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isSelected)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: bubble.offset)
                        .onTapGesture {
                            handleTap(bubble: bubble)
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            handleLongPress(bubble: bubble)
                        }
                }
                
                // Active Bubble Information Overlay
                // Ensure zIndex is high so it floats above everything
                if let selectedID = selectedBubbleID, let selected = bubbles.first(where: { $0.id == selectedID }) {
                    
                    let bubbleTopY = center.y + selected.offset.height - (selected.size / 2)
                    let showBelow = bubbleTopY < 80 // If near top, show below
                    
                    VStack(spacing: 4) {
                        Text(formatCurrency(selected.value))
                            .font(.custom("FKGroteskTrial-Bold", size: 16))
                            .foregroundColor(.primary)
                            .shadow(color: colorScheme == .dark ? .black : .white.opacity(0.5), radius: 2, x: 0, y: 1)
                        
                        Text(selected.name)
                            .font(.custom("FKGroteskTrial-Medium", size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(
                        Rectangle()
                            .fill(.regularMaterial) // Adaptive material
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .position(
                        x: center.x + selected.offset.width,
                        y: showBelow 
                            ? center.y + selected.offset.height + (selected.size / 2) + 35 // Below
                            : bubbleTopY - 35 // Above
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .zIndex(200)
                    .allowsHitTesting(false)
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let selectedID = selectedBubbleID, let selected = bubbles.first(where: { $0.id == selectedID }) {
                Button(action: {
                    let name = selected.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        print("📊 [Analytics] Triggering drilldown for: [\(name)]")
                        drilldownTarget = MerchantDrilldown(name: name)
                    } else {
                        print("⚠️ [Analytics] Selected bubble has empty name!")
                    }
                }) {
                    Text(selected.name)
                        .font(.custom("FKGroteskTrial-Medium", size: 12))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                .padding(.leading, 15)
                .padding(.bottom, 60)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }

        .frame(height: nil) // Allow parent to control height via frame()
        .padding(.horizontal, 20)
        .sheet(isPresented: $showDetail) {
            if let summary = detailedSummary {
                MerchantQuickStatsView(summary: summary)
                    .presentationDetents([.height(350)])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $drilldownTarget) { target in
            FinancialSummaryView(merchantId: "", merchantName: target.name)
                .environmentObject(authManager)
        }
    }
    
    private func handleTap(bubble: BubbleData) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            if selectedBubbleID == bubble.id {
                selectedBubbleID = nil
            } else {
                selectedBubbleID = bubble.id
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred() // Medium feedback on tap
            }
        }
    }
    
    private func handleLongPress(bubble: BubbleData) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred() // Heavy feedback on long press
        
        // Calculate Summary
        if let summary = AnalyticsManager.shared.computeMerchantSummary(merchantName: bubble.name) {
            self.detailedSummary = summary
            self.showDetail = true
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "£0"
    }
}

// Reusable View for Quick Stats (Bottom Sheet)
struct MerchantQuickStatsView: View {
    let summary: MerchantSummary
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    // Reusing styles from FinancialSummaryView
    private var primaryText: Color { colorScheme == .dark ? Color.white : Color.black }
    private var secondaryText: Color { colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6) }
    private var dividerTint: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1) }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                 Text(summary.merchant)
                     .font(.custom("FKGroteskTrial-Bold", size: 22))
                     .foregroundColor(primaryText)
                 
                 Spacer()
                 
                 Text(summary.category)
                     .font(.custom("FKGroteskTrial-Regular", size: 14))
                     .foregroundColor(secondaryText)
                     .padding(.horizontal, 10)
                     .padding(.vertical, 4)
             }
             .padding(.top, 20)
            
            Divider()
            
            // Stats Grid (Similar to FinancialSummaryView)
            VStack(spacing: 0) {
                // Row 1
                HStack(spacing: 0) {
                    metricItem(label: "This Month", value: formatCy(summary.periodStats.currentMonth.cleanTotal))
                    dividerVertical
                    metricItem(label: "This Year", value: formatCy(summary.periodStats.currentYear.cleanTotal))
                }
                .padding(.vertical, 8)
                
                Divider().opacity(0.5)
                
                // Row 2
                HStack(spacing: 0) {
                    metricItem(label: "Visits", value: "\(summary.insights.visitCount ?? 0)")
                    dividerVertical
                    metricItem(label: "Top Category", value: summary.insights.topCategory ?? "-")
                }
                .padding(.vertical, 8)
                
                Divider().opacity(0.5)
                
                // Row 3
                HStack(spacing: 0) {
                    metricItem(label: "Contribution", value: String(format: "%.1f%%", summary.insights.contributionPercentage ?? 0))
                    dividerVertical
                    metricItem(label: "Health Risk", value: "\(summary.insights.healthScore.unhealthyPercentage)%") // Show risk or health? let's show unhealthy as risk
                }
                .padding(.vertical, 8)
            }
            .background(Color(hex: colorScheme == .dark ? "1C1C1E" : "F5F5F7"))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
    
    func metricItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.custom("FKGroteskTrial-Regular", size: 12))
                .foregroundColor(secondaryText)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
    
    var dividerVertical: some View {
        Rectangle()
            .fill(dividerTint)
            .frame(width: 1, height: 30)
    }
    
    func formatCy(_ val: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: val)) ?? "£0"
    }
}



// Logic for Packing
struct BubbleLayoutEngine {
    static func calculateLayout(for items: [(name: String, value: Double, color: SwiftUI.Color, domain: String?)], containerSize: CGSize) -> [BubbleData] {
        guard !items.isEmpty else { return [] }
        
        // 1. Sort by Value Descending
        let sortedItems = items.sorted { $0.value > $1.value }
        let maxVal = sortedItems.first?.value ?? 1
        
        var parsedBubbles: [BubbleData] = []
        
        // 2. Assign Sizes (Area proportional to value)
        // Area = pi * r^2  => r = sqrt(Area/pi)
        // We map value -> Area directly.
        // Adjusted Max Radius to prevent clipping with more items:
        let maxRadius: CGFloat = 46 // Decreased to 46 for more space
        let minRadius: CGFloat = 28
        
        for item in sortedItems {
            // Normalized Size calculation
            let radius = max(minRadius, maxRadius * CGFloat(sqrt(item.value / maxVal)))
            let diameter = radius * 2
            
            parsedBubbles.append(BubbleData(
                name: item.name,
                value: item.value,
                color: item.color,
                offset: .zero,
                size: diameter,
                domain: item.domain
            ))
        }
        
        // 3. Spiral Packing
        var placedBubbles: [BubbleData] = []
        let boundsW = containerSize.width / 2
        let boundsH = containerSize.height / 2
        
        for i in 0..<parsedBubbles.count {
            var bubble = parsedBubbles[i]
            
            if i == 0 {
                bubble.offset = .zero
                placedBubbles.append(bubble)
                continue
            }
            
            // Spiral
            var angle: CGFloat = 0
            var dist: CGFloat = 0
            var found = false
            
            // Adjusted for balanced search speed vs precision
            let angleStep: CGFloat = 0.15 
            let distExpansion: CGFloat = 0.5 
            
            let maxIter = 4000 
            var iter = 0
            
            while !found && iter < maxIter {
                let x = cos(angle) * dist
                let y = sin(angle) * dist
                let candidateOffset = CGSize(width: x, height: y)
                
                // 1. Check Bounds - Keep away from edges
                let edgePadding: CGFloat = 10
                let r = bubble.size / 2
                
                // Stronger Top/Bottom padding
                let topPadding: CGFloat = 20
                
                // Check if we are within the container bounds
                if abs(x) + r > (boundsW - edgePadding) || abs(y) + r > (boundsH - topPadding) {
                    // Out of bounds - this spiral arm hit the wall
                } else {
                    // 2. Check Collision
                    var collision = false
                    for placed in placedBubbles {
                        let dx = candidateOffset.width - placed.offset.width
                        let dy = candidateOffset.height - placed.offset.height
                        
                        // Squared distance check is faster than sqrt
                        let distSq = dx*dx + dy*dy
                        let rSUM = (bubble.size / 2) + (placed.size / 2) + 24 // Padding 24
                        
                        if distSq < (rSUM * rSUM) {
                            collision = true
                            break
                        }
                    }
                    
                    if !collision {
                        bubble.offset = candidateOffset
                        placedBubbles.append(bubble)
                        found = true
                    }
                }
                
                if !found {
                     angle += angleStep
                     dist += distExpansion 
                }
                iter += 1
            }
            
            if !found {
                print("Skipped bubble \(bubble.name) due to space")
            } else {
                placedBubbles.append(bubble)
            }
        }
        
        return placedBubbles
    }
}

// Custom Cache to prevent flickering on selection (Z-Index change)
class ImageCache {
    static let shared = NSCache<NSString, UIImage>()
}

struct SimpleCachedImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: UIImage? = nil
    
    var body: some View {
        // Check cache synchronously to avoid flash
        if let url = url, let cached = ImageCache.shared.object(forKey: url.absoluteString as NSString) {
            content(Image(uiImage: cached))
        } else if let uiImage = image {
             content(Image(uiImage: uiImage))
        } else {
            placeholder()
                .task {
                    await loadImage()
                }
        }
    }
    
    private func loadImage() async {
        guard let url = url else { return }
        let key = url.absoluteString as NSString
        
        // Re-check cache in case another task loaded it
        if let cached = ImageCache.shared.object(forKey: key) {
            self.image = cached
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                ImageCache.shared.setObject(img, forKey: key)
                await MainActor.run {
                    self.image = img
                }
            }
        } catch {
            // Keep placeholder on error
        }
    }
}

struct BubbleView: View {
    let bubble: BubbleData
    var isSelected: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    // Logo.dev API Key
    private let logoDevToken = "pk_Sa5pkb0QQ3CfQPaZgFE7jA"
    
    var body: some View {
        // Prepare URL logic outside ZStack (ViewBuilder)
        let domain = bubble.domain
        let cleanName = bubble.name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "-", with: "")
            
        // Use provided domain or fallback to constructed cleanName.com
        var host = domain ?? "\(cleanName).com"
        
        // Clean the host (remove https://, http://, www.) to ensure logo.dev works
        if let url = URL(string: host), let scheme = url.scheme {
            host = host.replacingOccurrences(of: "\(scheme)://", with: "")
        }
        host = host.replacingOccurrences(of: "www.", with: "")
        // Remove trailing slashes
        if host.hasSuffix("/") { host.removeLast() }
        
        let urlString = "https://img.logo.dev/\(host)?token=\(logoDevToken)&size=200&format=png" + (colorScheme == .dark ? "&greyscale=true" : "")
        let logoUrl = URL(string: urlString)

        return ZStack {
            // 1. Base Dark Sphere (The "black dark color fill")
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "252525"), // Lighter center
                            Color(hex: "000000")  // Pure black edge
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: bubble.size / 1.5
                    )
                )
                .shadow(color: isSelected ? Color.white.opacity(0.3) : Color.black.opacity(0.6), radius: isSelected ? 15 : 8, x: 0, y: isSelected ? 0 : 6) // Glow when selected
            
            // 2. The Logo (Cached)
            SimpleCachedImage(url: logoUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(Circle())
                    .saturation(colorScheme == .dark ? 0 : 1) // Force monochrome in dark mode
                    .scaleEffect(0.65) // Logo sits inside the sphere
            } placeholder: {
                // Fallback / Loading
                Text(String(bubble.name.first ?? "?").uppercased())
                    .font(.custom("FKGroteskTrial-Bold", size: bubble.size * 0.4))
                    .foregroundColor(.gray)
            }
            .id(urlString) // Stable ID based on URL
            
            // 3. 3D Bevel/Glass Effect Overlay
            
            // Top Gloss (Reflection)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(2) // Inset slightly
            
            // Inner Shadow/Rim for "3D effect on the borders"
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3), // Top-left highlight
                            Color.black.opacity(0.8)   // Bottom-right shadow
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
            
            // 4. Selection Ring
            if isSelected {
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    .padding(-4)
            }
        }
        .frame(width: bubble.size, height: bubble.size)
    }
}
