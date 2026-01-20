import Foundation
import Combine

class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    @Published var allLineItems: [LineItem] = []
    @Published var isLoading = false
    
    private init() {}
    
    func refreshData(token: String) async throws {
        await MainActor.run { isLoading = true }
        do {
            let items = try await APIClient.shared.fetchAnalyticsLineItems(token: token)
            await MainActor.run {
                self.allLineItems = items
                self.isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
            throw error
        }
    }
    
    // MARK: - Local Aggregation Logic
    
    func getUniqueMerchants() -> [String] {
        let calendar = Calendar.current
        let now = Date()
        guard let twelveWeeksAgo = calendar.date(byAdding: .day, value: -84, to: now) else { return [] }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // Group by merchant and collect unique receipt IDs within the 12-week window
        var merchantVisitMap = [String: Set<String>]()
        
        for item in allLineItems {
            guard let name = item.merchantName,
                  let dateStr = item.transactionDate?.prefix(10),
                  let date = dateFormatter.date(from: String(dateStr)) else { continue }
            
            if date >= twelveWeeksAgo {
                let receiptId = item.receiptId ?? UUID().uuidString // Fallback to unique item if ID missing
                merchantVisitMap[name, default: Set<String>()].insert(receiptId)
            }
        }
        
        // Filter for merchants with at least 3 unique visits
        let filteredMerchants = merchantVisitMap.filter { $0.value.count >= 3 }
        
        // Return sorted by frequency (descending)
        return filteredMerchants.keys.sorted { merchantVisitMap[$0]!.count > merchantVisitMap[$1]!.count }
    }
    
    func computeMerchantSummary(merchantName: String) -> MerchantSummary? {
        let target = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredItems = allLineItems.filter { 
            ($0.merchantName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
        }
        
        guard !filteredItems.isEmpty else { return nil }
        
        let now = Date()
        let utcCalendar = getUTCCalendar()
        
        let startOfThisMonth = utcCalendar.date(from: utcCalendar.dateComponents([.year, .month], from: now))!
        let startOfPrevMonth = utcCalendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
        let startOfThisYear = utcCalendar.date(from: utcCalendar.dateComponents([.year], from: now))!
        let startOfPrevYear = utcCalendar.date(byAdding: .year, value: -1, to: startOfThisYear)!
        
        var thisMonthTotal: Double = 0
        var prevMonthTotal: Double = 0
        var thisYearTotal: Double = 0
        var prevYearTotal: Double = 0
        
        var categoryMap = [String: Double]()
        var itemMap = [String: Int]()
        var weeklyTrend = [String: Double]()
        var receiptIds = Set<String>()
        var storeCat: String? = nil
        
        var healthyCount = 0
        var unhealthyCount = 0
        let healthyCats = ["fruit", "vegetable", "meat", "poultry", "seafood", "dairy", "health", "fitness"]
        let unhealthyCats = ["snacks", "beverages", "alcohol", "fast_food", "dessert"]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        for item in filteredItems {
            guard let dateStr = item.transactionDate?.prefix(10),
                  let date = dateFormatter.date(from: String(dateStr)) else { continue }
            
            let price = item.totalPrice ?? 0
            
            // Period Stats
            if date >= startOfThisMonth {
                thisMonthTotal += price
                if let rid = item.receiptId { receiptIds.insert(rid) }
            } else if date >= startOfPrevMonth && date < startOfThisMonth {
                prevMonthTotal += price
            }
            
            if date >= startOfThisYear {
                thisYearTotal += price
            } else if date >= startOfPrevYear && date < startOfThisYear {
                prevYearTotal += price
            }
            
            // Trend (Last 12 months - Daily)
            let twelveMonthsAgo = utcCalendar.date(byAdding: .month, value: -12, to: now)!
            if date >= twelveMonthsAgo {
                let dayKey = dateFormatter.string(from: date)
                weeklyTrend[dayKey, default: 0] += price
            }
            
            // Insights
            let cat = item.mainCategory ?? "Other"
            categoryMap[cat, default: 0] += price
            itemMap[item.item ?? "Unknown", default: 0] += 1
            if storeCat == nil { storeCat = item.storeMainCategory }
            
            if healthyCats.contains(cat.lowercased()) { healthyCount += 1 }
            if unhealthyCats.contains(cat.lowercased()) { unhealthyCount += 1 }
        }
        
        // Totals for Contribution
        let totalSpendThisMonth = allLineItems.filter {
            guard let dateStr = $0.transactionDate?.prefix(10),
                  let date = dateFormatter.date(from: String(dateStr)) else { return false }
            return date >= startOfThisMonth
        }.reduce(0) { $0 + ($1.totalPrice ?? 0) }
        
        // Format Results
        let sortedWeeks = weeklyTrend.keys.sorted()
        let trendPoints = sortedWeeks.map { TrendPoint(date: $0, value: weeklyTrend[$0]) }
        
        let topCat = categoryMap.max(by: { $0.value < $1.value })?.key ?? "General"
        let topItem = itemMap.max(by: { $0.value < $1.value })?.key ?? "Unknown"
        
        let totalHealth = healthyCount + unhealthyCount
        let healthyPerc = totalHealth > 0 ? (Double(healthyCount) / Double(totalHealth) * 100).rounded() : 100
        
        let monthChange = prevMonthTotal > 0 ? ((thisMonthTotal - prevMonthTotal) / prevMonthTotal * 100) : (thisMonthTotal > 0 ? 100 : 0)
        let yearChange = prevYearTotal > 0 ? ((thisYearTotal - prevYearTotal) / prevYearTotal * 100) : (thisYearTotal > 0 ? 100 : 0)
        let contribution = totalSpendThisMonth > 0 ? (thisMonthTotal / totalSpendThisMonth * 100) : 0
        
        return MerchantSummary(
            merchant: merchantName,
            domain: nil,
            category: storeCat ?? topCat,
            periodStats: PeriodStats(
                currentMonth: StatDetail(total: thisMonthTotal, percentageChange: monthChange),
                currentYear: StatDetail(total: thisYearTotal, percentageChange: yearChange),
                previousMonth: StatDetail(total: prevMonthTotal, percentageChange: nil)
            ),
            trendGraph: trendPoints,
            insights: SpendingInsights(
                topCategory: topCat,
                topItem: topItem,
                healthScore: HealthScore(healthyPercentage: Int(healthyPerc), unhealthyPercentage: 100 - Int(healthyPerc)),
                contributionPercentage: contribution,
                visitCount: receiptIds.count
            )
        )
    }
    
    func computeMonthlyTrend(months: Int = 6) -> [AnalyticsTrend] {
        let utcCalendar = getUTCCalendar()
        let now = Date()
        
        // Generate last N months with 0 value
        var results: [AnalyticsTrend] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM" // Matches formatDate in UI
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        for i in (0..<months).reversed() {
            if let date = utcCalendar.date(byAdding: .month, value: -i, to: now) {
                let label = dateFormatter.string(from: date)
                results.append(AnalyticsTrend(date: label, value: 0))
            }
        }
        
        // Populate with actual data
        let itemDateFormatter = DateFormatter()
        itemDateFormatter.dateFormat = "yyyy-MM-dd"
        itemDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        for item in allLineItems {
            guard let dateStr = item.transactionDate?.prefix(10),
                  let date = itemDateFormatter.date(from: String(dateStr)) else { continue }
            
            let monthLabel = dateFormatter.string(from: date)
            if let index = results.firstIndex(where: { $0.date == monthLabel }) {
                let newValue = results[index].value + (item.totalPrice ?? 0)
                results[index] = AnalyticsTrend(date: monthLabel, value: newValue)
            }
        }
        
        // 3. Trim leading zeros (keep the window clean if first months are empty)
        while results.count > 1 && results.first?.value == 0 {
            results.removeFirst()
        }
        
        return results
    }
    
    private func getUTCCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
