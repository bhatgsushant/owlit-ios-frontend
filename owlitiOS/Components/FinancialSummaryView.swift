import SwiftUI

struct FinancialSummaryView: View {
    let merchant: String
    
    // Mock Data based on Merchant
    private var ticker: String {
        switch merchant.lowercased() {
        case "google", "alphabet": return "GOOGL"
        case "apple": return "AAPL"
        case "microsoft": return "MSFT"
        case "tesco": return "TSCO.L"
        default: return "MARKET"
        }
    }
    
    private var price: String {
        switch merchant.lowercased() {
        case "google", "alphabet": return "$308.61"
        case "apple": return "$225.50"
        default: return "$145.20"
        }
    }
    
    private var change: String {
        switch merchant.lowercased() {
        case "google", "alphabet": return "+1.60%"
        case "apple": return "-0.45%"
        default: return "+0.85%"
        }
    }
    
    private var isPositive: Bool {
        return !change.contains("-")
    }
    
    var body: some View {
        ZStack {
            Color(hex: "121212").ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Header
                    HStack(spacing: 12) {
                        // Logo Placeholder or AsyncImage if available
                        AsyncImage(url: URL(string: "https://img.logo.dev/\(cleanDomain(merchant))?token=pk_Sa5pkb0QQ3CfQPaZgFE7jA&size=60&retina=true")) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fit)
                            } else {
                                Circle().fill(Color.orange)
                                    .overlay(Text(merchant.prefix(1)).font(.title2).bold().foregroundColor(.white))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(merchant.capitalized + " Inc.")
                                .font(.system(size: 18, weight: .semibold)) // FKGrotesk fallback
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Text(ticker)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                                Text("• NASDAQ") // Placeholder
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.6))
                                Text("🇺🇸")
                                    .font(.system(size: 11))
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "bell")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 32) // Clear Drag Indicator
                    
                    // MARK: - Hero Stats
                    HStack(spacing: 16) {
                        statsCard(price: price, change: change, isPositive: isPositive, time: "4:00 PM EST ☀️")
                        statsCard(price: "$309.00", change: "+0.13%", isPositive: true, time: "5:32 PM 🌙")
                    }
                    
                    // MARK: - Main Chart Card
                    VStack(spacing: 16) {
                        // Controls
                        HStack {
                            HStack(spacing: 4) {
                                Text("1D")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(white: 0.15))
                            .cornerRadius(8)
                            
                            Spacer()
                        }
                        
                        // Chart (Mock Path)
                        ChartShape(data: [100, 105, 102, 110, 108, 120, 118, 130, 145, 142, 150, 160])
                            .stroke(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                            )
                            .frame(height: 120)
                            .background(
                                VStack {
                                    Divider().background(Color.gray.opacity(0.2))
                                    Spacer()
                                    Divider().background(Color.gray.opacity(0.2))
                                    Spacer()
                                    Divider().background(Color.gray.opacity(0.2))
                                }
                            )
                            .overlay(
                                Text("Powered by Owlit")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray.opacity(0.5))
                                    .offset(y: -40)
                            )
                        
                        // Grid details
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            detailItem(label: "Market Cap", value: "3.72T")
                            detailItem(label: "P/E Ratio", value: "30.46")
                            detailItem(label: "Div Yield", value: "0.27%")
                            detailItem(label: "52W Range", value: "$142-328")
                            detailItem(label: "Volume", value: "45M")
                            detailItem(label: "EPS", value: "$10.13")

                        }
                        .padding(.top, 16)
                    }
                    .padding(16)
                    .background(Color(white: 0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    
                    // Footer Action Button
                    Button(action: {}) {
                        Text("Placeholder Action")
                            .font(.custom("FKGroteskTrial-Medium", size: 16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Components
    
    func statsCard(price: String, change: String, isPositive: Bool, time: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(price)
                    .font(.custom("FKGroteskTrial-Medium", size: 18)) // Or system if not available
                    .foregroundColor(.white)
                
                Text("\(change) 1D")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(isPositive ? Color(hex: "56CCF2") : Color(hex: "FF3B30"))
            }
            
            Text("Dec 19 at \(time)")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
    
    func detailItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
             Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    private func cleanDomain(_ name: String) -> String {
         return name.lowercased().filter { $0.isLetter || $0.isNumber } + ".com"
    }
}

// Simple Chart Shape
struct ChartShape: Shape {
    let data: [Double]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }
        
        let minVal = data.min() ?? 0
        let maxVal = data.max() ?? 100
        let range = maxVal - minVal
        
        let stepX = rect.width / CGFloat(data.count - 1)
        
        // Start
        let startY = rect.height - CGFloat((data[0] - minVal) / range) * rect.height
        path.move(to: CGPoint(x: 0, y: startY))
        
        for i in 1..<data.count {
            let x = CGFloat(i) * stepX
            let y = rect.height - CGFloat((data[i] - minVal) / range) * rect.height
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

#Preview {
    FinancialSummaryView(merchant: "Google")
}
