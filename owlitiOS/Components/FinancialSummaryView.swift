import SwiftUI

struct FinancialSummaryView: View {
    let merchantId: String
    let merchantName: String
    
    // Computed property for internal usage (display)
    var merchant: String { resolvedMerchantName.isEmpty ? merchantName : resolvedMerchantName }
    
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    // Init
    init(merchantId: String, merchantName: String) {
        self.merchantId = merchantId
        self.merchantName = merchantName
    }
    
    // State
    @State private var summary: MerchantSummary?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var resolvedMerchantName: String = ""
    @State private var showGlobalAnalytics = false
    @State private var startAnimation = false
    @State private var chartProgress: CGFloat = 0.0 // Animation State
    @State private var selectedIndex: Int? = nil // Chart Interaction State
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Background - Creamy White
            Color(hex: "FAFAF5").ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else if let data = summary {
                contentView(data: data)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.5)) {
                            startAnimation = true
                        }
                    }
            }
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        guard let token = authManager.token else {
            errorMessage = "User not authenticated"
            isLoading = false
            return
        }
        
        do {
            // 1. Resolve Canonical Merchant Name from Server
            let resolution = try await APIClient.shared.resolveMerchant(name: merchantName, token: token)
            resolvedMerchantName = resolution.displayName
            
            // 2. Fetch Server-Side Aggregated Summary
            let data = try await APIClient.shared.fetchMerchantSummary(merchant: resolution.id, token: token)
            
            self.summary = data
            
        } catch {
             print("Error fetching summary: \(error)")
             errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    
    // MARK: - Views
    
    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .black))
            .scaleEffect(1.2)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Something went wrong")
            .font(.headline)
            .foregroundColor(.black)
            
            Text(message)
            .font(.caption)
            .foregroundColor(.gray)
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
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spending Trend (12 Weeks)")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal)
                        
                        trendSection(data: data)
                    }

                    insightsGrid(data: data)
                }
                .padding(16)
                .background(Color.white) // White card on Cream background
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                )
                
                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .padding(.top, 24)
        }
    }
    
    // MARK: - Sub-Components
    
    private func headerSection(summary: MerchantSummary) -> some View {
        HStack(spacing: 14) {
             AsyncImage(url: URL(string: "https://img.logo.dev/\(cleanDomain(merchant))?token=pk_Sa5pkb0QQ3CfQPaZgFE7jA&size=80&retina=true")) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
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
                // Name handled by parent view header
                HStack(spacing: 6) {
                    Text(summary.category)
                        .font(.custom("FKGroteskTrial-Regular", size: 14))
                        .foregroundColor(.gray)
                } 
            }
            Spacer()
        }
        .padding(.top, 12)
    }
    
    private func heroStatsSection(data: MerchantSummary) -> some View {
        HStack(spacing: 12) {
            heroCard(
                label: "THIS MONTH",
                value: data.periodStats.currentMonth.cleanTotal,
                percentChange: data.periodStats.currentMonth.percentageChange
            )
            
            heroCard(
                label: "THIS YEAR",
                value: data.periodStats.currentYear.cleanTotal,
                percentChange: data.periodStats.currentYear.percentageChange
            )
        }
    }
    
    private func heroCard(label: String, value: Double, percentChange: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("FKGroteskTrial-Regular", size: 12))
                .foregroundColor(Color.gray)
            
            VStack(alignment: .leading, spacing: 2) {
                // Animated Currency
                AnimatedText(value: startAnimation ? value : 0, formatType: .currency)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.black)
                
                if let change = percentChange {
                    HStack(spacing: 4) {
                        Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        AnimatedText(value: startAnimation ? abs(change) : 0, formatType: .percent)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(change > 0 ? Color.red : Color.green)
                } else {
                    Text("-")
                        .font(.custom("FKGroteskTrial-Regular", size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FAFAF5")) // Creamy White
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 1.5)
        )
    }
    
    private func trendSection(data: MerchantSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if data.trendGraph.isEmpty {
                Text("Not enough data")
                    .font(.custom("FKGroteskTrial-Regular", size: 12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .foregroundColor(.gray)
            } else {
                let recentData = data.trendGraph 
                VStack(spacing: 0) {
                    ZStack {
                        // Dense Silver Grid (Tighter)
                        MeshGrid(spacing: 3)
                            .stroke(Color(hex: "D3D3D3").opacity(0.5), style: StrokeStyle(lineWidth: 0.5))
                        
                        ChartShape(data: recentData, closed: true)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.6), Color.orange.opacity(0.1)], // Intense Orange
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            // Wipe mask for the fill
                            .mask(
                                Rectangle()
                                    .scaleEffect(x: chartProgress, y: 1, anchor: .leading)
                            )
                            .overlay(
                                ChartShape(data: recentData)
                                    .trim(from: 0, to: chartProgress) // Animate stroke drawing
                                    .stroke(
                                        LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                                    )
                            )
                            
                        // Data Labels (Static) - Only show if NO interaction is happening
                        if chartProgress > 0.9 && selectedIndex == nil { 
                            GeometryReader { geo in
                                let points = calculatePoints(data: recentData, rect: geo.frame(in: .local))
                                ForEach(0..<points.count, id: \.self) { i in
                                    // Show Label for Max, Min, and Last
                                    if shouldShowLabel(index: i, data: recentData) {
                                        Text(String(format: "£%.0f", recentData[i]))
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.black)
                                            .padding(2)
                                            .background(Color.white.opacity(0.8))
                                            .cornerRadius(4)
                                            .position(x: points[i].x, y: points[i].y - 12)
                                    }
                                }
                            }
                        }
                        
                        // Interactive Tooltip Overlay
                        GeometryReader { geo in
                            let points = calculatePoints(data: recentData, rect: geo.frame(in: .local))
                            
                            // Ghost Interaction Layer
                            Color.white.opacity(0.001) // Invisible but interactable
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let stepX = geo.size.width / CGFloat(recentData.count - 1)
                                            let index = Int(round(value.location.x / stepX))
                                            let safeIndex = max(0, min(recentData.count - 1, index))
                                            
                                            // Haptic & State Update
                                            if safeIndex != self.selectedIndex {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                self.selectedIndex = safeIndex
                                            }
                                        }
                                        .onEnded { _ in
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                withAnimation {
                                                    self.selectedIndex = nil
                                                }
                                            }
                                        }
                                )
                            
                            if let idx = selectedIndex, idx < points.count {
                                let point = points[idx]
                                let weeksAgo = recentData.count - 1 - idx
                                let date = Calendar.current.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date()) ?? Date()
                                let dateString = (weeksAgo == 0) ? "This Week" : date.formatted(.dateTime.day().month())
                                
                                // Vertical Line
                                Path { path in
                                    path.move(to: CGPoint(x: point.x, y: 0))
                                    path.addLine(to: CGPoint(x: point.x, y: geo.size.height))
                                }
                                .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                
                                // Dot
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .position(point)
                                
                                // Tooltip (Above point)
                                VStack(spacing: 2) {
                                    Text(dateString)
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.gray)
                                    
                                    Text(String(format: "£%.2f", recentData[idx]))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(8)
                                .position(x: max(35, min(geo.size.width - 35, point.x)), y: max(24, point.y - 35))
                            }
                        }
                    }
                    .frame(height: 160)
                    .onAppear {
                        // Delay slightly to ensure transition finishes before animating
                        // Slow down animation to 3.0s
                        withAnimation(.easeInOut(duration: 3.0).delay(0.2)) {
                            chartProgress = 1.0
                        }
                    }
                    
                    // Simple X-Axis
                    HStack {
                        Text("12 weeks ago")
                        Spacer()
                        Text("Today")
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func insightsGrid(data: MerchantSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            
            insightCard(
                icon: "arrow.counterclockwise",
                title: "PREV MONTH",
                value: "N/A",
                rawValue: data.periodStats.previousMonth.cleanTotal,
                formatType: .currency
            )
            
            insightCard(
                icon: "chart.pie.fill",
                title: "CONTRIBUTION",
                value: "N/A",
                rawValue: data.insights.contributionPercentage ?? 0,
                formatType: .percent
            )
            
            insightCard(
                icon: "figure.walk",
                title: "VISITS",
                value: "\(data.insights.visitCount ?? 0)",
                rawValue: Double(data.insights.visitCount ?? 0),
                formatType: .number
            )
            
            insightCard(
                icon: "tag.fill",
                title: "TOP CATEGORY",
                value: data.insights.topCategory ?? "General"
            )
            
            insightCard(
                icon: "cart.fill",
                title: "TOP ITEM",
                value: data.insights.topItem ?? "Unknown"
            )
            
            // Health Score Card (Span 1 or custom)
            healthScoreCard(score: data.insights.healthScore)
        }
    }
    
    private func insightCard(icon: String, title: String, value: String, rawValue: Double? = nil, formatType: AnimatedText.FormatType? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                Text(title)
                    .font(.custom("FKGroteskTrial-Regular", size: 9))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            if let dVal = rawValue, let fmt = formatType {
                AnimatedText(value: startAnimation ? dVal : 0, formatType: fmt)
                    .font(.custom("FKGroteskTrial-Regular", size: 14).weight(.semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(value)
                    .font(.custom("FKGroteskTrial-Regular", size: 14).weight(.semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
        .background(Color(hex: "FAFAF5")) // Creamy White
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 1.5)
        )
    }
    
    private func healthScoreCard(score: HealthScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                Text("HEALTH")
                    .font(.custom("FKGroteskTrial-Regular", size: 10))
                    .foregroundColor(.gray)
            }
            
            HStack(alignment: .bottom, spacing: 4) {
                // Animated Health Score
                AnimatedText(value: startAnimation ? Double(score.healthyPercentage) : 0, formatType: .number)
                    .font(.custom("FKGroteskTrial-Regular", size: 14).weight(.semibold))
                    .foregroundColor(.black)
                Text("%")
                    .font(.custom("FKGroteskTrial-Regular", size: 14).weight(.semibold))
                    .foregroundColor(.black)
                    
                Text("Healthy")
                    .font(.custom("FKGroteskTrial-Regular", size: 8))
                    .foregroundColor(.green)
                    .padding(.bottom, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
        .background(Color(hex: "FAFAF5"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 1.5)
        )
    }
    
    // Placeholder Action Button
    private var actionButton: some View {
        Button(action: {
            triggerHaptic(style: .medium)
            showGlobalAnalytics = true
        }) {
            Text("See All Transactions")
                .font(.custom("FKGroteskTrial-Regular", size: 16).weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black) // Dark button
                .cornerRadius(14)
        }
        .padding(.top, 8)
        .fullScreenCover(isPresented: $showGlobalAnalytics) {
            if let token = authManager.token, let url = URL(string: "https://owlit.vercel.app/insights") {
                 // SFSafariViewController automatically handles the "Done" button when presented modally
                 SafariView(url: url, token: token)
                     .ignoresSafeArea()
            } else {
                Text("Invalid URL or Unauthenticated")
            }
        }
    }
    
    // MARK: - Helpers
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    private func cleanDomain(_ name: String) -> String {
        let simple = name.lowercased().filter { $0.isLetter || $0.isNumber }
        return simple + ".com"
    }
    
    private func shouldShowLabel(index: Int, data: [Double]) -> Bool {
        guard !data.isEmpty else { return false }
        let maxIndex = data.indices.max(by: { data[$0] < data[$1] })
        let minIndex = data.indices.min(by: { data[$0] < data[$1] })
        let lastIndex = data.count - 1
        
        return index == maxIndex || index == minIndex || index == lastIndex
    }
    
    private func calculatePoints(data: [Double], rect: CGRect) -> [CGPoint] {
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

struct MeshGrid: Shape {
    let spacing: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for y in stride(from: 0, to: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        for x in stride(from: 0, to: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        return path
    }
}

#Preview {
    FinancialSummaryView(merchantId: "test", merchantName: "Tesco")
        .environmentObject(AuthManager())
}
