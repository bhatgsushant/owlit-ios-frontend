import SwiftUI
import Charts

struct Analytics: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authManager: AuthManager
    
    // MARK: - State
    @State private var timeRange: String = "month" // "week", "month", "quarter", "year"
    @State private var viewMode: String = "value" // "value", "percent"
    @State private var drillLevel: DrillLevel = .main
    @State private var selectedCategory: String? = nil
    @State private var selectedSubCategory: String? = nil
    
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
        ("All", "all")
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
    private var gridColor: Color { colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.02) }
    private var dividerTint: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1) }

    var body: some View {
        ZStack {
            cardBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                headerSection
                    .padding(.top, 20)
                
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
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
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
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category")
                        .font(.custom("FKGroteskTrial-Bold", size: 32))
                        .foregroundColor(primaryText)
                    Text("Drilldown")
                        .font(.custom("FKGroteskTrial-Bold", size: 32))
                        .foregroundColor(primaryText)
                }
                
                Spacer()
                
                // Time Range Picker
                timeRangePicker
            }
            .padding(.horizontal, 20)
            
        }
    }
    
    private var timeRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(timeRanges, id: \.1) { (label, value) in
                    Button(action: {
                        triggerHaptic(style: .light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            timeRange = value
                        }
                    }) {
                        Text(label)
                            .font(.custom("FKGroteskTrial-Bold", size: 14))
                            .foregroundColor(timeRange == value ? primaryText : secondaryText)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                ZStack {
                                    if timeRange == value {
                                        Capsule()
                                            .fill(primaryText.opacity(colorScheme == .dark ? 0.12 : 0.06))
                                            .matchedGeometryEffect(id: "timeRange", in: animationNamespace)
                                    }
                                }
                            )
                    }
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .stroke(dividerTint, lineWidth: 1)
        )
        .frame(maxWidth: 260) // Limit width to prevent overflow
    }

    @Namespace private var animationNamespace

    // MARK: - Category Drilldown Card
    private var categoryDrilldownCard: some View {
        VStack(spacing: 20) {
            // Controls (Back, All Categories, Toggle)
            HStack(spacing: 12) {
                if drillLevel != .main {
                    Button(action: goBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                        .font(.custom("FKGroteskTrial-Medium", size: 13))
                        .foregroundColor(primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(cardBg.opacity(0.5))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(dividerTint, lineWidth: 1))
                    }
                }
                
                Text(currentDrillTitle)
                    .font(.custom("FKGroteskTrial-Medium", size: 13))
                    .foregroundColor(primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(cardBg.opacity(0.5))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(dividerTint, lineWidth: 1))
                
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
            }
            
            // The Chart
            chartContainer
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
    
    private var chartContainer: some View {
        let entries = filteredEntries
        
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
                                    Color(hex: "9AA6B2").opacity(opacity), // Violet
                                    Color(hex: "9AA6B2").opacity(opacity)  // Pink
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(6)
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
            let data = await Task.detached(priority: .userInitiated) { [currentItemsWithDates, currentDrillLevel, currentSelectedCategory, currentSelectedSubCategory] () -> [ChartEntry] in
                let filtered = self.filterItemsByPreParsedDates(currentItemsWithDates)
                var tempEntries: [ChartEntry] = []
                
                switch currentDrillLevel {
                case .main:
                    var map: [String: Double] = [:]
                    for (item, _) in filtered {
                        let name = item.mainCategory ?? "Other"
                        let price = item.totalPrice ?? 0
                        map[name, default: 0] += price
                    }
                    tempEntries = self.sortAndFormat(map)
                    
                case .sub:
                    guard let cat = currentSelectedCategory else { return [] }
                    var map: [String: Double] = [:]
                    for (item, _) in filtered where (item.mainCategory ?? "").localizedCaseInsensitiveCompare(cat) == .orderedSame {
                        let name = item.subCategory ?? "Other"
                        let price = item.totalPrice ?? 0
                        map[name, default: 0] += price
                    }
                    tempEntries = self.sortAndFormat(map)
                    
                case .item:
                    guard let sub = currentSelectedSubCategory else { return [] }
                    var map: [String: Double] = [:]
                    for (item, _) in filtered where (item.subCategory ?? "").localizedCaseInsensitiveCompare(sub) == .orderedSame {
                        let name = item.normalizedName ?? item.item
                        let price = item.totalPrice ?? 0
                        map[name, default: 0] += price
                    }
                    tempEntries = self.sortAndFormat(map)
                }
                return tempEntries
            }.value
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.filteredEntries = data
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
        return map.map { ChartEntry(label: $0.key.uppercased(), value: $0.value, percent: total > 0 ? ($0.value / total) * 100 : 0) }
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
            // Fetch flattened line items directly from the view via API
            let items = try await APIClient.shared.fetchAnalyticsLineItems(token: token)
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(primaryText.opacity(0.6))
                        .padding(8)
                        .background(cardBg)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(primaryText.opacity(0.1), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
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
