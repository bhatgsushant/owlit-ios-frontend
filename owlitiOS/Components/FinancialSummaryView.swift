import SwiftUI

struct FinancialSummaryView: View {
    let merchantId: String
    let merchantName: String
    
    // Computed property for internal usage (display)
    var merchant: String { currentMerchantName }
    
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Adaptive Colors
    private var adaptiveBg: Color { colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white }
    private var adaptiveCardBg: Color { colorScheme == .dark ? Color.white.opacity(0.03) : Color.white }
    private var primaryText: Color { colorScheme == .dark ? Color.white : Color.black }
    private var secondaryText: Color { colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6) }
    private var tertiaryText: Color { colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4) }
    private var gridLineColor: Color { colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.02) }
    private var dividerTint: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1) }
    private var tooltipBg: Color { colorScheme == .dark ? Color(hex: "2C2C2E").opacity(0.95) : Color.white.opacity(0.95) }
    
    // Init
    // List of merchants for dropdown
    @State private var availableMerchants: [String] = [] // Loaded dynamically

    init(merchantId: String, merchantName: String) {
        self.merchantId = merchantId
        self.merchantName = merchantName
        _currentMerchantName = State(initialValue: merchantName)
        _availableMerchants = State(initialValue: [merchantName])
        print("DEBUG FinancialSummaryView[Init]: name=[\(merchantName)]")
    }
    
    // State
    @State private var currentMerchantName: String
    @State private var summary: MerchantSummary?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var resolvedMerchantName: String = ""
    @State private var showGlobalAnalytics = false
    @State private var startAnimation = false
    @State private var chartProgress: CGFloat = 0.0 // Animation State
    @State private var selectedIndex: Int? = nil // Chart Interaction State
    @State private var isBarChart = false // Default to Line for 12-month density

    
    // Recent Receipts State
    @State private var merchantReceipts: [ReceiptData] = []
    @State private var receiptToEdit: ReceiptData?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var receiptIdToDelete: String?
    
    // MARK: - Body
    // MARK: - Body
    var body: some View {
        ZStack {
            // MARK: - Mesh Background
            ZStack {
                adaptiveBg
                MeshGrid(spacing: 5)
                    .stroke(gridLineColor, lineWidth: 0.5)
            }
            .ignoresSafeArea()
            
            // Content Layer (always rendered if available, or loading overlay)
            if let error = errorMessage {
                errorView(message: error)
            } else {
                // Show content if available, else placeholders or nothing
                if let data = summary {
                    contentView(data: data)
                        .transition(.opacity)
                        .opacity(isLoading ? 0.5 : 1.0) // Dim content while reloading
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.8)) {
                                startAnimation = true
                            }
                        }
                }
                
                // Loading Overlay (Non-blocking for background)
                if isLoading && summary == nil {
                    loadingView
                }
            }
        }
        .task(id: merchantName) {
            await loadData()
        }
    }
    
    // MARK: - Data Loading
    private func loadData(isSwitching: Bool = false) async {
        isLoading = true
        errorMessage = nil
        
        if isSwitching {
            withAnimation {
                startAnimation = false
            }
        }
        
        guard let token = authManager.token else {
            errorMessage = "User not authenticated"
            isLoading = false
            return
        }
        
        do {
            // 1. Refresh global raw data if the manager is empty or we are doing a forced refresh
            if AnalyticsManager.shared.allLineItems.isEmpty {
                try await AnalyticsManager.shared.refreshData(token: token)
            }
            
            // 2. Load user's merchants list from local data
            await fetchUserMerchants(token: token)
            
            // 3. Compute Summary locally for the current merchant
            // HARDEN: Use the reactive currentMerchantName if it exists, otherwise fall back to the property
            let targetMerchant = (currentMerchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) 
                ? merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
                : currentMerchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if targetMerchant.isEmpty {
                 print("❌ [FinancialSummaryView] Error: Both currentMerchantName and merchantName are empty!")
                 errorMessage = "System Error: Missing store name"
                 isLoading = false
                 return
            }
            
            print("DEBUG FinancialSummaryView[Load]: target=[\(targetMerchant)], itemsCount=\(AnalyticsManager.shared.allLineItems.count)")
            
            // Re-sync local state if we had to use the property
            if currentMerchantName != targetMerchant {
                await MainActor.run { self.currentMerchantName = targetMerchant }
            }
            
            // Try to compute (Manager now does fuzzy matching + canonical fallback)
            let manager = AnalyticsManager.shared
            guard let localSummary = manager.computeMerchantSummary(merchantName: targetMerchant) else {
                print("DEBUG FinancialSummaryView[Error]: Failed lookup for [\(targetMerchant)] among \(manager.allLineItems.count) items.")
                errorMessage = "No data found for \(targetMerchant)"
                isLoading = false
                return
            }
            
            // 4. Fetch Receipts for this Merchant (Existing local logic)
            await fetchMerchantReceipts(merchantName: targetMerchant, token: token)
            
            withAnimation(.easeInOut(duration: 0.4)) {
                self.summary = localSummary
            }
            
            // Re-trigger animations
            try? await Task.sleep(nanoseconds: 100_000_000)
            withAnimation(.easeOut(duration: 0.8)) {
                startAnimation = true
            }       
            
        } catch {
             print("Error updating local analytics: \(error)")
             if !AnalyticsManager.shared.allLineItems.isEmpty {
                 print("✅ [FinancialSummaryView] Using cached data despite error.")
                 // Retry logic flow with cached data
                 // We need to re-run the summary computation logic here or ensure it ran?
                 // Actually, if refreshData failed, we jumped strictly to catch.
                 // We need to manually trigger the local computation part which was skipped.
                 
                 // COPY-PASTE logic from try block or extract to helper?
                 // Extracting to helper 'computeLocalData' is best, but for now I will inline the fallback logic
                 // to avoid major refactor risk in a one-shot tool.
                 
                 await computeSummaryLocally()
             } else {
                 errorMessage = error.localizedDescription
             }
        }
        isLoading = false
    }
    
    // Extracted helper to reuse in both try and catch blocks
    private func computeSummaryLocally() async {
        let targetMerchant = (currentMerchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) 
            ? merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            : currentMerchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Re-sync local state if we had to use the property
        if currentMerchantName != targetMerchant {
            await MainActor.run { self.currentMerchantName = targetMerchant }
        }
        
        let manager = AnalyticsManager.shared
        
        // Ensure user merchants are loaded (from cache)
        if availableMerchants.isEmpty || availableMerchants.count == 1 {
             let merchants = manager.getUniqueMerchants()
             await MainActor.run {
                 self.availableMerchants = merchants.map { $0.capitalized }
             }
        }

        guard let localSummary = manager.computeMerchantSummary(merchantName: targetMerchant) else {
            errorMessage = "No data found for \(targetMerchant)"
            return
        }
        
        // 4. Fetch Receipts (Try network, ignore error if offline, maybe we should cache receipt lists too? 
        // Receipts are fetched via APIClient.shared.fetchReceipts separately.
        // Persistence was only added to Analytics Line Items. 
        // So 'Recent Receipts' list might be empty offline. That is acceptable for now.)
        // We will wrap this in try? to avoid crashing the view if offline.
        await fetchMerchantReceipts(merchantName: targetMerchant, token: authManager.token ?? "")
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.summary = localSummary
            }
        }
        
        // Re-trigger animations
        try? await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run { 
            withAnimation(.easeOut(duration: 0.8)) {
                self.startAnimation = true
            }
        }
    }

    private func fetchMerchantReceipts(merchantName: String, token: String) async {
        do {
            let allReceipts = try await APIClient.shared.fetchReceipts(token: token)
            // Fuzzy match merchant name
            let filtered = allReceipts.filter { receipt in
                let name = (receipt.merchantName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let target = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return name == target || name.contains(target) || target.contains(name)
            }
            
            // Simple sort by date (fallback to ID if date same)
            let sorted = filtered.sorted { 
                let d1 = $0.transactionDate ?? ""
                let d2 = $1.transactionDate ?? ""
                if d1 != d2 { return d1 > d2 }
                return ($0.id ?? "") > ($1.id ?? "")
            }
            
            let recent = Array(sorted.prefix(5))
            
            await MainActor.run {
                self.merchantReceipts = recent
            }
        } catch {
            print("Failed to fetch merchant receipts: \(error)")
        }
    }

    private func fetchUserMerchants(token: String) async {
        // Now handled by loadData using local AnalyticsManager
        let merchants = AnalyticsManager.shared.getUniqueMerchants()
        await MainActor.run {
            self.availableMerchants = merchants.map { $0.capitalized }
        }
    }

    // MARK: - Views
    
    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white)) // White tint
            .scaleEffect(1.2)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Something went wrong")
            .font(.headline)
            .foregroundColor(primaryText)
            
            Text(message)
            .font(.caption)
            .foregroundColor(secondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            
            Button("Try Again") {
                Task { await loadData() }
            }
            .padding(.top, 8)
        }
    }
    
    private func contentView(data: MerchantSummary) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Spacer().frame(height: 20) // Optional spacing if needed
                
                VStack(spacing: 12) {
                    headerSection(summary: data) 
                    
                    heroStatsSection(data: data)
                    
                    VStack(spacing: 0) {
                        trendSection(data: data)
                            .padding(.top, 8)
                        
                        Divider().background(dividerTint)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        
                        insightsGrid(data: data)
                            .padding(.bottom, 12)
                    }
                    .background(
                        ZStack {
                            adaptiveCardBg
                            MeshGrid(spacing: 5)
                                .stroke(gridLineColor, lineWidth: 0.5)
                        }
                    )
                    .cornerRadius(8)
                    // 3D Shadow/Elevation Effect
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

                    allReceiptsSection()
                        .padding(.top, 16) // Extra space between metrics and table

                    actionButton
                }
                .padding(16)
                .sheet(isPresented: $showingEditSheet) {
                    if var receipt = receiptToEdit {
                        // Ensure existingReceiptId is set for ScanReceiptView to know it's an update
                        let _ = { receipt.existingReceiptId = receipt.id }()
                        
                        ScanReceiptView(image: UIImage(), data: receipt, saveMode: .server) { updated in
                             Task { await loadData(isSwitching: false) }
                        }
                    }
                }
                .alert("Delete Receipt", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        if let id = receiptIdToDelete {
                            performDelete(id: id)
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete this receipt? This action cannot be undone.")
                }

                .background(adaptiveBg) // Theme Adaptive Background
                .cornerRadius(20) // Standard Rounded Rectangle
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .padding(.top, 24)
        }
    }
    
    // MARK: - Sub-Components
    
    // MARK: - Sub-Components
    
    func headerSection(summary: MerchantSummary) -> some View {
        HStack(spacing: 14) {
             let logoDomain = summary.domain ?? cleanDomain(merchant)
             AsyncImage(url: URL(string: "https://img.logo.dev/\(logoDomain)?token=pk_Sa5pkb0QQ3CfQPaZgFE7jA&size=80&retina=true")) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                } else {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(merchant.prefix(1).uppercased())
                                .font(.custom("FKGroteskTrial-Regular", size: 20).weight(.bold))
                                .foregroundColor(.white)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Dropdown Menu for Merchant Selection
                Menu {
                    ForEach(availableMerchants, id: \.self) { name in
                        Button(name) {
                            if currentMerchantName != name {
                                currentMerchantName = name
                                // Trigger background reload
                                Task { await loadData(isSwitching: true) }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currentMerchantName)
                            .font(.custom("FKGroteskTrial-Bold", size: 20))
                            .foregroundColor(primaryText)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(secondaryText)
                        
                        // Subtle Loading Indicator for Switching
                        if isLoading && summary != nil {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(primaryText)
                        }
                    }
                }
                
                HStack(spacing: 6) {
                    Text(summary.category)
                        .font(.custom("FKGroteskTrial-Regular", size: 14))
                        .foregroundColor(secondaryText)
                } 
            }
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(tertiaryText)
            }
        }
        .padding(.top, 12)
    }
    
    func heroStatsSection(data: MerchantSummary) -> some View {
        HStack {
            heroCard(
                label: "THIS MONTH",
                value: data.periodStats.currentMonth.cleanTotal,
                percentChange: data.periodStats.currentMonth.percentageChange
            )
            
            Spacer()
            
            dividerView
            
            Spacer()
            
            heroCard(
                label: "THIS YEAR",
                value: data.periodStats.currentYear.cleanTotal,
                percentChange: data.periodStats.currentYear.percentageChange
            )
        }
    }
    
    func heroCard(label: String, value: Double, percentChange: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("FKGroteskTrial-Regular", size: 12))
                .foregroundColor(secondaryText)
            
            VStack(alignment: .leading, spacing: 2) {
                // Animated Currency
                AnimatedText(value: startAnimation ? value : 0, formatType: .currency)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(primaryText)
                
                if let change = percentChange {
                    HStack(spacing: 4) {
                        Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        AnimatedText(value: startAnimation ? abs(change) : 0, formatType: .percent)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(change > 0 ? Color(hex: "FF3B30") : Color.green) // Adjusted Red for visibility
                } else {
                    Text("-")
                        .font(.custom("FKGroteskTrial-Regular", size: 12))
                        .foregroundColor(tertiaryText)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                adaptiveCardBg
                MeshGrid(spacing: 5)
                    .stroke(gridLineColor, lineWidth: 0.5)
            }
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
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
    
    func trendSection(data: MerchantSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let recentData = data.safeTrendGraph
            let values = recentData.compactMap { $0.value }
            
            if recentData.isEmpty {
                Text("Not enough data")
                    .font(.custom("FKGroteskTrial-Regular", size: 12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .foregroundColor(.gray)
            } else {
                let maxVal = (values.max() ?? 1.0) * 1.1
                let graphHeight: CGFloat = 180 // Unified height for both charts
                let averageSpend = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
                let maxDiff = values.map { abs($0 - averageSpend) }.max() ?? 1.0

                VStack(spacing: 8) {
                    // Chart Header with Toggle
                    HStack {
                        Text("Spending Trend")
                            .font(.custom("FKGroteskTrial-Medium", size: 14))
                            .foregroundColor(secondaryText)
                        
                        Spacer()
                        
                        // Switch Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isBarChart.toggle()
                                triggerHaptic(style: .light)
                            }
                        }) {
                            Image(systemName: isBarChart ? "chart.line.uptrend.xyaxis" : "chart.bar.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(primaryText.opacity(0.6))
                                .padding(8)
                                .background(adaptiveCardBg)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(primaryText.opacity(0.1), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    HStack(alignment: .bottom, spacing: 16) {
                        // Chart Area
                        ZStack {
                            if isBarChart {
                                // BAR CHART
                                HStack(alignment: .bottom, spacing: 4) {
                                    ForEach(0..<recentData.count, id: \.self) { i in
                                        let point = recentData[i]
                                        let val = point.value ?? 0
                                        let heightRatio = CGFloat(val / (maxVal == 0 ? 1 : maxVal))
                                        let barHeight = heightRatio * graphHeight 
                                        
                                        let date = parseTrendDate(point.date, index: i, total: recentData.count)
                                        
                                        // Color Logic
                                        let diff = val - averageSpend
                                        let deviationParam = maxDiff == 0 ? 0 : abs(diff) / maxDiff
                                        let intensity = 0.3 + (0.7 * deviationParam)
                                        let baseColor = diff > 0.01 ? Color.red : Color.green 
                                        
                                        // Interaction State
                                        let isSelected = (selectedIndex == i)
                                        
                                        VStack(spacing: 4) {
                                            Spacer()
                                            
                                            // Bar (ultra-thin for daily density)
                                            RoundedRectangle(cornerRadius: 1)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [baseColor.opacity(intensity), baseColor.opacity(intensity * 0.6)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .frame(height: max(4, barHeight * chartProgress))
                                                .frame(width: recentData.count > 100 ? 2 : nil) // Thin bars for density
                                                .opacity(isSelected ? 1.0 : 0.8)
                                                .scaleEffect(x: isSelected ? 1.05 : 1.0, y: 1.0, anchor: .bottom)
                                            
                                            // X-Axis Label (Filtered for density)
                                            let calendar = Calendar.current
                                            let isFirstOfMonth = calendar.component(.day, from: date) == 1
                                            
                                            if isFirstOfMonth || recentData.count < 30 {
                                                Text(formatXAxisDate(date, isFullYear: recentData.count > 100))
                                                    .font(.custom("FKGroteskTrial-Regular", size: 8).weight(.semibold))
                                                    .foregroundColor(isSelected ? .white : .gray)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.5)
                                                    .frame(height: 10)
                                            } else {
                                                Spacer().frame(height: 10)
                                            }
                                        }
                                        .frame(maxWidth: .infinity) 
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                    removal: .opacity
                                ))
                            } else {
                                // LINE CHART
                                GeometryReader { lineGeo in
                                    let w = lineGeo.size.width
                                    let h = graphHeight // Use unified height
                                    let topOffset: CGFloat = 36 // Match the spacer height in Bar Chart
                                    
                                    // Calculate the vertical split point for the gradient based on average spend
                                    let avgYRatio = CGFloat(1.0 - (averageSpend / maxVal))
                                    let gradientStops: [Gradient.Stop] = [
                                        .init(color: .red, location: 0),
                                        .init(color: .red, location: max(0, avgYRatio - 0.02)),
                                        .init(color: Color.emerald, location: min(1, avgYRatio + 0.02)),
                                        .init(color: Color.emerald, location: 1)
                                    ]
                                    
                                    let lineGradient = LinearGradient(stops: gradientStops, startPoint: .top, endPoint: .bottom)
                                    
                                    ZStack {
                                        let points: [CGPoint] = (0..<recentData.count).map { i in
                                            let val = recentData[i].value ?? 0
                                            let x = (CGFloat(i) / CGFloat(recentData.count - 1)) * w
                                            let y = topOffset + (h - (CGFloat(val / maxVal) * h))
                                            return CGPoint(x: x, y: y)
                                        }

                                        // 1. Curved Line
                                        Path { path in
                                            guard points.count >= 2 else { return }
                                            path.move(to: points[0])
                                            
                                            for i in 1..<points.count {
                                                let p1 = points[i-1]
                                                let p2 = points[i]
                                                let midPoint = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                                                
                                                if i == 1 {
                                                    path.addLine(to: midPoint)
                                                } else {
                                                    path.addQuadCurve(to: midPoint, control: p1)
                                                }
                                                
                                                if i == points.count - 1 {
                                                    path.addLine(to: p2)
                                                }
                                            }
                                        }
                                        .trim(from: 0, to: chartProgress)
                                        .stroke(lineGradient, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                                        
                                        // 2. Curved Area Fill
                                        Path { path in
                                            guard points.count >= 2 else { return }
                                            path.move(to: CGPoint(x: 0, y: topOffset + h))
                                            path.addLine(to: points[0])
                                            
                                            for i in 1..<points.count {
                                                let p1 = points[i-1]
                                                let p2 = points[i]
                                                let midPoint = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                                                
                                                if i == 1 {
                                                    path.addLine(to: midPoint)
                                                } else {
                                                    path.addQuadCurve(to: midPoint, control: p1)
                                                }
                                                
                                                if i == points.count - 1 {
                                                    path.addLine(to: p2)
                                                }
                                            }
                                            
                                            path.addLine(to: CGPoint(x: w, y: topOffset + h))
                                            path.closeSubpath()
                                        }
                                        .fill(
                                            LinearGradient(
                                                stops: [
                                                    .init(color: .red.opacity(0.12), location: 0),
                                                    .init(color: .red.opacity(0.04), location: avgYRatio),
                                                    .init(color: Color.emerald.opacity(0.12), location: avgYRatio),
                                                    .init(color: Color.emerald.opacity(0.02), location: 1)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .opacity(chartProgress)
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                    removal: .opacity
                                ))
                            }
                            
                            // Interaction / Tooltip Layer
                            GeometryReader { geo in
                                Color.white.opacity(0.001)
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                let width = geo.size.width
                                                let index = Int(value.location.x / (width / CGFloat(recentData.count)))
                                                let safeIndex = max(0, min(recentData.count - 1, index))
                                                if selectedIndex != safeIndex {
                                                    selectedIndex = safeIndex
                                                    triggerHaptic(style: .light)
                                                }
                                            }
                                            .onEnded { _ in withAnimation { selectedIndex = nil } }
                                    )
                                
                                if let idx = selectedIndex, idx < recentData.count {
                                    let step = geo.size.width / CGFloat(recentData.count)
                                    let barCenterX = (step * CGFloat(idx)) + (step / 2)
                                    let point = recentData[idx]
                                    
                                    Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 1, height: geo.size.height - 20)
                                        .position(x: barCenterX, y: (geo.size.height - 20) / 2)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(String(format: "£%.2f", point.value ?? 0)).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(primaryText)
                                        Text(formatTooltipDate(parseTrendDate(point.date, index: idx, total: recentData.count))).font(.custom("FKGroteskTrial-Medium", size: 12)).foregroundColor(secondaryText)
                                    }
                                    .padding(8).background(tooltipBg).cornerRadius(8).shadow(radius: 4)
                                    .position(x: max(60, min(geo.size.width - 60, barCenterX)), y: 40)
                                }
                            }
                        }
                        .frame(height: 230)
                        .padding(.horizontal, 12)
                        
                        // Y-Axis Labels
                        VStack(alignment: .trailing) {
                            Text(String(format: "£%.0f", maxVal))
                            Spacer()
                            Text(String(format: "£%.0f", maxVal / 2))
                            Spacer()
                            Text("£0")
                        }
                        .font(.custom("FKGroteskTrial-Medium", size: 12))
                        .foregroundColor(Color.gray)
                        .frame(height: 200)
                        .padding(.trailing, 8)
                    }
                    .padding(.vertical, 4)
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0)) {
                        chartProgress = 1.0
                    }
                }
            }
        }
    }
    
    // MARK: - Chart Helpers
    private func parseTrendDate(_ string: String?, index: Int, total: Int) -> Date {
        let calendar = Calendar.current
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        guard let s = string, s.count >= 10 else {
            // Fallback to daily interpolation if date is missing
            let daysAgo = total - 1 - index
            return utcCalendar.startOfDay(for: utcCalendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date())
        }
        
        // Extract YYYY-MM-DD manually to ignore any time/TZ fluff
        let components = s.prefix(10).split(separator: "-")
        if components.count == 3,
           let year = Int(components[0]),
           let month = Int(components[1]),
           let day = Int(components[2]) {
            
            var dc = DateComponents()
            dc.year = year
            dc.month = month
            dc.day = day
            dc.hour = 0
            dc.minute = 0
            dc.second = 0
            
            if let date = utcCalendar.date(from: dc) {
                // print("DEBUG - Bar [\(index)]: Server '\(s)' -> Parsed '\(date)'")
                return date
            }
        }
        
        return utcCalendar.startOfDay(for: Date())
    }
    
    private func formatTooltipDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatXAxisDate(_ date: Date, isFullYear: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = isFullYear ? "MMM" : "MM/dd"
        return formatter.string(from: date)
    }

    
    func insightsGrid(data: MerchantSummary) -> some View {
        VStack(spacing: 0) {
            // Row 1
            HStack(spacing: 0) {
                stockMetricRow(label: "Prev Month", value: String(format: "£%.2f", data.periodStats.previousMonth.cleanTotal))
                dividerView
                stockMetricRow(label: "Visits", value: "\(data.insights.visitCount ?? 0)")
            }
            .padding(.vertical, 6)
            
            // Row 2
            HStack(spacing: 0) {
                stockMetricRow(label: "Contribution", value: String(format: "%.1f%%", data.insights.contributionPercentage ?? 0))
                dividerView
                stockMetricRow(label: "Health Score", value: "\(data.insights.healthScore.healthyPercentage)%")
            }
            .padding(.vertical, 6)
            
            // Row 3 (Categories)
            HStack(spacing: 0) {
                stockMetricRow(label: "Top Category", value: data.insights.topCategory ?? "-")
                dividerView
                stockMetricRow(label: "Average Spend", value: calculatedAverageSpend(data))
            }
            .padding(.vertical, 6)
        }
        .padding(.top, 4)
    }
    
    var dividerView: some View {
        Rectangle()
            .fill(dividerTint)
            .frame(width: 1, height: 24)
            .padding(.horizontal, 16)
    }
    
    func stockMetricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("FKGroteskTrial-Regular", size: 14))
                .foregroundColor(secondaryText)
            
            Spacer()
            
            Text(value.uppercased())
                .font(.custom("FKGroteskTrial-Regular", size: 14))
                .foregroundColor(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }
    
    // Placeholder Action Button
    var actionButton: some View {
        Button(action: {
            triggerHaptic(style: .medium)
            showGlobalAnalytics = true
        }) {
            HStack(spacing: 8) {
                Text("See more insights")
                    .font(.custom("FKGroteskTrial-Medium", size: 16))
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 14))
            }
            .foregroundColor(primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(adaptiveCardBg)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(dividerTint, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 10, x: 0, y: 5)
        }
        .padding(.top, 8)
        .fullScreenCover(isPresented: $showGlobalAnalytics) {
            if let url = URL(string: "https://owlit.vercel.app/insights") {
                 // Passing nil for token to prevent redirect loops. SFSafariViewController shares cookies.
                 SafariView(url: url, token: nil)
                     .ignoresSafeArea()
            } else {
                Text("Invalid URL")
            }
        }
    }
    
    // MARK: - Recently Scanned Table
    
    private func allReceiptsSection() -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recently Scanned")
                    .font(.custom("FKGroteskTrial-Bold", size: 20))
                    .foregroundColor(primaryText)
                Spacer()
            }
            
            VStack(spacing: 0) {
                // Table Header
                HStack {
                    Text("Date")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Rectangle()
                        .fill(dividerTint)
                        .frame(width: 1, height: 12)
                    
                    Text("Total")
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Rectangle()
                        .fill(dividerTint)
                        .frame(width: 1, height: 12)
                    
                    Text("Action")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.custom("FKGroteskTrial-Medium", size: 11))
                .foregroundColor(secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                
                Divider().background(dividerTint)
                
                if merchantReceipts.isEmpty {
                    Text("No receipts found")
                        .font(.custom("FKGroteskTrial-Regular", size: 14))
                        .foregroundColor(secondaryText)
                        .padding(.vertical, 32)
                } else {
                    ForEach(merchantReceipts) { receipt in
                        receiptRow(receipt: receipt)
                        if receipt.id != merchantReceipts.last?.id {
                            Divider().background(dividerTint)
                        }
                    }
                }
            }
            .background(
                ZStack {
                    adaptiveCardBg
                    MeshGrid(spacing: 5)
                        .stroke(gridLineColor, lineWidth: 0.5)
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
    }
    
    private func receiptRow(receipt: ReceiptData) -> some View {
        HStack {
            // Date
            Text(formatDateStr(receipt.transactionDate))
                .font(.custom("FKGroteskTrial-Regular", size: 14))
                .foregroundColor(primaryText.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Rectangle()
                .fill(dividerTint)
                .frame(width: 1, height: 24)
            
            // Total
            Text(formatCurrency(receipt.totalAmount ?? 0))
                .font(.custom("FKGroteskTrial-Bold", size: 14))
                .foregroundColor(primaryText)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Rectangle()
                .fill(dividerTint)
                .frame(width: 1, height: 24)
            
            // Actions
            HStack(spacing: 18) {
                Button(action: { editReceipt(receipt) }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue.opacity(0.8))
                }
                
                Button(action: { deleteReceipt(receipt.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
    }
    
    private func formatDateStr(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "—" }
        // server returns yyyy-MM-dd
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            let displayForm = DateFormatter()
            displayForm.dateFormat = "MMM d, yyyy"
            return displayForm.string(from: date)
        }
        return dateStr
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "£\(amount)"
    }
    
    private func editReceipt(_ receipt: ReceiptData) {
        self.receiptToEdit = receipt
        self.showingEditSheet = true
    }
    
    private func deleteReceipt(_ id: String?) {
        guard let receiptId = id else { return }
        self.receiptIdToDelete = receiptId
        self.showingDeleteAlert = true
        triggerHaptic(style: .light)
    }
    
    private func performDelete(id: String) {
        guard let token = authManager.token else { return }
        
        Task {
            do {
                try await APIClient.shared.deleteReceipt(receiptId: id, token: token)
                // Reload
                await loadData(isSwitching: false)
                triggerHaptic(style: .medium)
            } catch {
                print("Failed to delete receipt: \(error)")
            }
        }
    }
    
    // MARK: - Helpers
    func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func cleanDomain(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("co-op") || lower.contains("coop") {
            return "coop.co.uk"
        }
        if lower.contains("waitrose") { return "waitrose.com" } // explicit safety
        
        let simple = lower.filter { $0.isLetter || $0.isNumber }
        return simple + ".com"
    }
    
    func shouldShowLabel(index: Int, data: [Double]) -> Bool {
        guard !data.isEmpty else { return false }
        let maxIndex = data.indices.max(by: { data[$0] < data[$1] })
        let minIndex = data.indices.min(by: { data[$0] < data[$1] })
        let lastIndex = data.count - 1
        
        return index == maxIndex || index == minIndex || index == lastIndex
    }
    
    func calculatePoints(data: [Double], rect: CGRect) -> [CGPoint] {
        var points: [CGPoint] = []
        guard data.count > 1 else { return points }
        
        // Match scaling logic in ChartShape
        let minVal = 0.0
        let maxData = data.max() ?? 1.0
        let maxVal = maxData == 0 ? 100.0 : maxData * 1.1
        let range = maxVal - minVal
        
        let stepX = rect.width / CGFloat(data.count - 1)
        
        for i in 0..<data.count {
            let x = CGFloat(i) * stepX
            let val = data[i]
            let y = rect.height - CGFloat((val - minVal) / range) * rect.height
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }
    func calculatedAverageSpend(_ data: MerchantSummary) -> String {
        // defined in server: visitCount is trips/receipts in the current month
        // currentMonth.cleanTotal is spend in the current month
        // We can approximate Average Spend (Ticket Size) for this month.
        if let visits = data.insights.visitCount, visits > 0 {
            let avg = data.periodStats.currentMonth.cleanTotal / Double(visits)
            return String(format: "£%.2f", avg)
        }
        // Fallback placeholder if no data for this month (as requested)
        return "£15.40"
    }
}

// MARK: - Chart Components

struct ChartShape: Shape {
    let data: [Double]
    var closed: Bool = false
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }
        
        let minVal = 0.0
        let maxData = data.max() ?? 1.0
        let maxVal = maxData == 0 ? 100.0 : maxData * 1.1
        let range = maxVal - minVal
        
        let stepX = rect.width / CGFloat(data.count - 1)
        
        let firstY = rect.height - CGFloat((data[0] - minVal) / range) * rect.height
        path.move(to: CGPoint(x: 0, y: firstY))
        
        for i in 1..<data.count {
            let x = CGFloat(i) * stepX
            let val = data[i]
            let y = rect.height - CGFloat((val - minVal) / range) * rect.height
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        if closed {
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
        
        return path
    }
}



#Preview {
    FinancialSummaryView(merchantId: "test", merchantName: "Tesco")
        .environmentObject(AuthManager())
}
