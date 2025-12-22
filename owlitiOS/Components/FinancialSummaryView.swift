import SwiftUI

struct FinancialSummaryView: View {
    let merchant: String
    @EnvironmentObject var authManager: AuthManager
    
    // State
    @State private var summary: MerchantSummary?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Background
            Color(hex: "121212").ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else if let data = summary {
                contentView(data: data)
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
        do {
            if let token = authManager.token {
                self.summary = try await APIClient.shared.fetchMerchantSummary(merchant: merchant, token: token)
            } else {
                throw URLError(.userAuthenticationRequired)
            }
        } catch {
            print("Error loading summary: \(error)")
            // Detailed error for debugging
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    errorMessage = "Missing key: \(key.stringValue) - \(context.debugDescription)"
                case .typeMismatch(let type, let context):
                    errorMessage = "Type mismatch: \(type) - \(context.debugDescription)"
                case .valueNotFound(let type, let context):
                    errorMessage = "Value not found: \(type) - \(context.debugDescription)"
                case .dataCorrupted(let context):
                    errorMessage = "Data corrupted - \(context.debugDescription)"
                @unknown default:
                    errorMessage = "Decoding error: \(error.localizedDescription)"
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
    
    // MARK: - Views
    
    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(1.2)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            
            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(.white)
            
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
                // Unified Card Container
                VStack(spacing: 12) { // Compact spacing
                    // 1. Header with Logo
                    headerSection(data: data)
                    
                    // 2. Big Numbers (Month/Year)
                    heroStatsSection(data: data)
                    
                    // 3. Trend Chart
                    trendSection(data: data)
                    
                    // 4. Insights Grid
                    insightsGrid(data: data)
                }
                .padding(16) // Reduced internal padding
                .background(
                    LinearGradient(
                        colors: [Color(hex: "0F200F"), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 12) // 3D Shadow Pop
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // 5. Footer Action
                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Sub-Components
    
    private func headerSection(data: MerchantSummary) -> some View {
        HStack(spacing: 14) {
             AsyncImage(url: URL(string: "https://img.logo.dev/\(cleanDomain(merchant))?token=pk_Sa5pkb0QQ3CfQPaZgFE7jA&size=80&retina=true")) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
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
                Text(data.merchant.capitalized)
                    .font(.custom("FKGroteskTrial-Regular", size: 20).weight(.bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    Text(data.category)
                        .font(.custom("FKGroteskTrial-Regular", size: 14))
                        .foregroundColor(.gray)
                    
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 3, height: 3)
                    
                    Text("Details")
                        .font(.custom("FKGroteskTrial-Regular", size: 14))
                        .foregroundColor(.gray)
                } 
            }
            
            Spacer()
            
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .foregroundColor(.gray)
        }
        .padding(.top, 12) // Reduced top padding
    }
    
    private func heroStatsSection(data: MerchantSummary) -> some View {
        HStack(spacing: 12) {
            heroCard(
                label: "THIS MONTH",
                value: formatCurrency(data.periodStats.currentMonth.cleanTotal),
                percentChange: data.periodStats.currentMonth.percentageChange
            )
            
            heroCard(
                label: "THIS YEAR",
                value: formatCurrency(data.periodStats.currentYear.cleanTotal),
                percentChange: data.periodStats.currentYear.percentageChange
            )
        }
    }
    
    private func heroCard(label: String, value: String, percentChange: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) { // Reduced spacing
            Text(label)
                .font(.custom("FKGroteskTrial-Regular", size: 12))
                .foregroundColor(Color(white: 0.6))
            
            VStack(alignment: .leading, spacing: 2) { // Reduced spacing
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced)) // Reduced font (20 -> 15)
                    .foregroundColor(.white)
                
                if let change = percentChange {
                    HStack(spacing: 4) {
                        Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%.1f%%", abs(change)))
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
        .padding(12) // Reduced padding (16 -> 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "0F200F"), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
    }
    
    private func trendSection(data: MerchantSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) { // Tighter spacing
            if data.cleanTrendGraph.isEmpty {
                Text("Not enough data")
                    .font(.custom("FKGroteskTrial-Regular", size: 12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .foregroundColor(.gray)
            } else {
                let recentData = Array(data.cleanTrendGraph.suffix(7))
                VStack(spacing: 0) { // Spacing 0 to connect chart and axis bg
                    // Chart Area with Grid
                    ZStack {
                        // Mesh Grid
                        MeshGrid(spacing: 5)
                            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [1, 2]))
                        
                            // Chart
                        ChartShape(data: recentData, closed: true)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "DFFF00").opacity(0.4), Color(hex: "DFFF00").opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                ChartShape(data: recentData)
                                    .stroke(Color(hex: "DFFF00"), lineWidth: 2)
                            )
                        
                        // Data Labels Overlay
                        GeometryReader { geo in
                            ForEach(Array(recentData.enumerated()), id: \.offset) { index, value in
                                let maxVal = (recentData.max() ?? 1.0) * 1.1
                                let yHeight = maxVal > 0 ? CGFloat(value / maxVal) * geo.size.height : 0
                                let xPos = CGFloat(index) * (geo.size.width / CGFloat(max(1, recentData.count - 1)))
                                
                                Text(String(format: "%.0f", value))
                                    .font(.custom("FKGroteskTrial-Regular", size: 9))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                                    .position(x: xPos, y: geo.size.height - yHeight - 15)
                            }
                        }
                    }
                    .frame(height: 160) // Reduced chart height for compactness
                    // Removed padding to align with hero cards
                    
                    // X-Axis Labels with Individual Backgrounds
                    HStack {
                        Text("7d")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer()
                        
                        Text("5d")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Spacer()
                        
                        Text("3d")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Spacer()
                        
                        Text("1d")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.custom("FKGroteskTrial-Regular", size: 10))
                    .foregroundColor(Color(hex: "DFFF00"))
                    .padding(.vertical, 8)
                    // Removed horizontal padding to align with chart
                }
                .padding(.vertical, 8)
            }

        }
        // Removed .background and .cornerRadius to "remove the card" styling
    }
    
    private func insightsGrid(data: MerchantSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            
            insightCard(
                icon: "arrow.counterclockwise",
                title: "PREV MONTH",
                value: formatCurrency(data.periodStats.previousMonth.cleanTotal)
            )
            
            insightCard(
                icon: "chart.pie.fill",
                title: "CONTRIBUTION",
                value: String(format: "%.1f%%", data.insights.contributionPercentage ?? 0)
            )
            
            insightCard(
                icon: "figure.walk",
                title: "VISITS",
                value: "\(data.insights.visitCount ?? 0)"
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
            
            // Health Score Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                    Text("HEALTH")
                        .font(.custom("FKGroteskTrial-Regular", size: 10)) // Extra Small
                        .foregroundColor(.gray)
                }
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(data.insights.healthScore.healthyPercentage)%")
                        .font(.custom("FKGroteskTrial-Regular", size: 14).weight(.semibold)) // Smaller Value
                        .foregroundColor(.white)
                    Text("Good") // Shortened "Healthy" to fit
                        .font(.custom("FKGroteskTrial-Regular", size: 8))
                        .foregroundColor(.gray)
                        .padding(.bottom, 2)
                }
            }
            .padding(10) // Reduced Padding
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 80) // Fixed height for alignment
            .background(
                LinearGradient(
                    colors: [Color(hex: "0F200F"), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
        }
    }
    
    private func insightCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10)) // Smaller Icon
                    .foregroundColor(.blue)
                Text(title)
                    .font(.custom("FKGroteskTrial-Regular", size: 9)) // Extra Small Title
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Text(value)
                .font(.custom("FKGroteskTrial-Regular", size: 14).weight(.semibold)) // Smaller Value Font
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8) // Shrink if needed (e.g. log item names)
        }
        .padding(10) // Reduced Padding
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80) // Fixed Height for alignment
        .background(
            LinearGradient(
                colors: [Color(hex: "0F200F"), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
    }
    
    private var actionButton: some View {
        Button(action: {}) {
            Text("See All Transactions")
                .font(.custom("FKGroteskTrial-Regular", size: 16).weight(.semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(14)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    private func cleanDomain(_ name: String) -> String {
        // Remove spaces and special chars to help simple logo finding
        let simple = name.lowercased().filter { $0.isLetter || $0.isNumber }
        return simple + ".com"
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: NSNumber(value: value)) ?? "£0.00"
    }
}

// MARK: - Chart Shape
struct ChartShape: Shape {
    let data: [Double]
    var closed: Bool = false
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }
        
        let minVal = 0.0
        // Use a fixed max if all zero, else max
        let maxData = data.max() ?? 1.0
        let maxVal = maxData == 0 ? 100.0 : maxData * 1.1
        let range = maxVal - minVal
        
        let stepX = rect.width / CGFloat(data.count - 1)
        
        // Start first point
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

// MARK: - Mesh Grid Shape
struct MeshGrid: Shape {
    let spacing: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Horizontal lines
        for y in stride(from: 0, to: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        // Vertical lines
        for x in stride(from: 0, to: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        return path
    }
}

// Preview
#Preview {
    FinancialSummaryView(merchant: "Uber")
}
