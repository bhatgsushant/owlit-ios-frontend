
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
                // Header inside scroll view to scroll with content
                HStack {
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Color(.systemGray4))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                VStack(spacing: 12) {
                    headerSection(summary: data) // Re-using header logic for logo? Layout might be redundant.
                    // Let's hide the top header and rely on the internal card header or merge them.
                    // The previous design had a "card" style. Let's keep the card style.
                    
                    heroStatsSection(data: data)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spending Trend (12 Weeks)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        trendSection(data: data)
                    }

                    insightsGrid(data: data)
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "0F200F"), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
    
    private var displayName: String {
        return resolvedMerchantName.isEmpty ? merchantName : resolvedMerchantName
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
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("FKGroteskTrial-Regular", size: 12))
                .foregroundColor(Color(white: 0.6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
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
                let recentData = data.trendGraph // Use full graph or slice if needed
                VStack(spacing: 0) {
                    ZStack {
                        MeshGrid(spacing: 20) // adjusted spacing
                            .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [1, 2]))
                        
                        ChartShape(data: recentData, closed: true)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "00FF9C").opacity(0.4), Color(hex: "00FF9C").opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                ChartShape(data: recentData)
                                    .stroke(Color(hex: "00FF9C"), lineWidth: 2)
                            )
                        
                        // Data Labels (Optional: Show max/min or last point)
                    }
                    .frame(height: 160)
                    
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
            
            // Health Score Card (Span 1 or custom)
            healthScoreCard(score: data.insights.healthScore)
        }
    }
    
    private func insightCard(icon: String, title: String, value: String) -> some View {
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
            
            Text(value)
                .font(.custom("FKGroteskTrial-Regular", size: 14).weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
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
                Text("\(score.healthyPercentage)%")
                    .font(.custom("FKGroteskTrial-Regular", size: 14).weight(.semibold))
                    .foregroundColor(.white)
                Text("Healthy")
                    .font(.custom("FKGroteskTrial-Regular", size: 8))
                    .foregroundColor(.green)
                    .padding(.bottom, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // Placeholder Action Button
    private var actionButton: some View {
        Button(action: {
            showGlobalAnalytics = true
        }) {
            Text("See All Transactions")
                .font(.custom("FKGroteskTrial-Regular", size: 16).weight(.semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
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
    private func cleanDomain(_ name: String) -> String {
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

// MARK: - Chart Components (Reused or Definitions)

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
