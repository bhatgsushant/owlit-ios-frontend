import Foundation
import Combine

class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    @Published var allLineItems: [LineItem] = []
    @Published var storeDomainMap: [String: String] = [:]
    @Published var storeTypeMap: [String: String] = [:]
    @Published var isLoading = false
    private var lastRefreshTask: Task<Void, Error>?

    private init() {}
    
    func refreshData(token: String) async throws {
        // Prevent concurrent refreshes
        if let existingTask = lastRefreshTask {
            return try await existingTask.value
        }
        
        let task = Task {
            await MainActor.run { isLoading = true }
            defer { Task { await MainActor.run { isLoading = false } } }
            
            // 1. Load from disk first if empty (Optimization for startup)
            if allLineItems.isEmpty {
                await loadFromDisk()
            }
            
            async let itemsTask = APIClient.shared.fetchAnalyticsLineItems(token: token)
            async let storeInfoTask = APIClient.shared.fetchStoreInfo(token: token)
            
            do {
                let (items, storeInfos) = try await (itemsTask, storeInfoTask)
                
                await MainActor.run {
                    self.allLineItems = items
                    self.storeDomainMap = Dictionary(storeInfos.compactMap { info in
                        guard let d = info.domain, !d.isEmpty else { return nil }
                        return (info.merchantName.lowercased(), d)
                    }, uniquingKeysWith: { (first, _) in first })
                    
                    self.storeTypeMap = Dictionary(storeInfos.compactMap { info in
                        guard let t = info.storeType, !t.isEmpty else { return nil }
                        return (info.merchantName.lowercased(), t)
                    }, uniquingKeysWith: { (first, _) in first })
                }
                
                // 2. Save success to disk
                await saveToDisk()
                
            } catch {
                print("⚠️ [AnalyticsManager] Offline or Error: \(error.localizedDescription). Using cached data.")
                if allLineItems.isEmpty {
                    await loadFromDisk() // Try one last time if we failed and have nothing
                }
                throw error
            }
        }
        
        self.lastRefreshTask = task
        defer { self.lastRefreshTask = nil }
        
        return try await task.value
    }
    
    // MARK: - Persistence
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var lineItemsFile: URL {
        documentsDirectory.appendingPathComponent("analytics_line_items.json")
    }
    
    private var storeMapFile: URL {
        documentsDirectory.appendingPathComponent("analytics_store_map.json")
    }
    
    private var storeTypeMapFile: URL {
        documentsDirectory.appendingPathComponent("analytics_store_type_map.json")
    }
    
    private func saveToDisk() async {
        let items = self.allLineItems
        let map = self.storeDomainMap
        
        Task.detached(priority: .background) {
            do {
                let encoder = JSONEncoder()
                let itemsData = try encoder.encode(items)
                try itemsData.write(to: self.lineItemsFile)
                
                let mapData = try encoder.encode(map)
                try mapData.write(to: self.storeMapFile)
                
                let typeMapData = try encoder.encode(self.storeTypeMap)
                try typeMapData.write(to: self.storeTypeMapFile)
                
                print("💾 [AnalyticsManager] Saved \(items.count) items to disk.")
            } catch {
                print("❌ [AnalyticsManager] Failed to save to disk: \(error)")
            }
        }
    }
    
    func ensureDataLoaded() async {
        if allLineItems.isEmpty {
            await loadFromDisk()
        }
    }
    
    private func loadFromDisk() async {
        print("📂 [AnalyticsManager] Loading from disk...")
        do {
            if FileManager.default.fileExists(atPath: lineItemsFile.path) {
                let data = try Data(contentsOf: lineItemsFile)
                let items = try JSONDecoder().decode([LineItem].self, from: data)
                
                await MainActor.run {
                    self.allLineItems = items
                }
                print("✅ [AnalyticsManager] Loaded \(items.count) items from disk.")
            }
            
            if FileManager.default.fileExists(atPath: storeMapFile.path) {
                let data = try Data(contentsOf: storeMapFile)
                let map = try JSONDecoder().decode([String: String].self, from: data)
                
                await MainActor.run {
                    self.storeDomainMap = map
                }
            }
            
            if FileManager.default.fileExists(atPath: storeTypeMapFile.path) {
                let data = try Data(contentsOf: storeTypeMapFile)
                let map = try JSONDecoder().decode([String: String].self, from: data)
                
                await MainActor.run {
                    self.storeTypeMap = map
                }
            }
        } catch {
            print("❌ [AnalyticsManager] Failed to load from disk: \(error)")
        }
    }
    
    // Fuzzy lookup for domain
    func getDomain(for merchantName: String) -> String? {
        let normalized = merchantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Exact Match
        if let domain = storeDomainMap[normalized] {
            return domain
        }
        
        // 2. Fuzzy Match (DB key contained in Receipt Name)
        // e.g. Receipt: "Co-op Food", DB: "Co-op" -> Match
        // We look for a key in the map that is a prefix or contained in the receipt name
        // Sort keys by length descending to match "Tesco Extra" before "Tesco"
        let keys = storeDomainMap.keys.sorted { $0.count > $1.count }
        
        for key in keys {
            if normalized.contains(key) {
                return storeDomainMap[key]
            }
        }
        
        return nil
    }
    
    // Fuzzy lookup for store type
    func getStoreType(for merchantName: String) -> String? {
        let normalized = merchantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Exact Match
        if let type = storeTypeMap[normalized] {
            return type
        }
        
        // 2. Fuzzy Match
        let keys = storeTypeMap.keys.sorted { $0.count > $1.count }
        
        for key in keys {
            if normalized.contains(key) {
                return storeTypeMap[key]
            }
        }
        
        return nil
    }
    
    // Exact Logic from FinancialSummaryView: Prioritize store_main_category from history
    func getStoreCategory(for merchantName: String) -> String? {
        let target = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. Look for explicit store category in history (using first non-nil)
        if let storeCat = allLineItems.first(where: { 
            guard let m = $0.merchantName else { return false }
            return m.lowercased().contains(target) && $0.storeMainCategory != nil 
        })?.storeMainCategory {
             return storeCat
        }
        
        // 2. Fallback to Store Type Map (from store_info table)
        if let type = getStoreType(for: merchantName) {
            return type
        }
        
        return nil
    }
    
    // Get all unique store types for dropdowns
    func getAvailableStoreTypes() -> [String] {
        var types = Set<String>()
        
        // 1. From Store Type Map (Master List)
        types.formUnion(storeTypeMap.values)
        
        // 2. From History (in case some are not in master list)
        for item in allLineItems {
            if let t = item.storeMainCategory, !t.isEmpty {
                types.insert(t)
            }
        }
        
        // 3. Ensure defaults exist
        let defaults = ["grocery", "restaurant", "retail", "fuel", "service", "medical", "transport", "other"]
        types.formUnion(defaults)
        
        return Array(types).sorted()
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
    
    // Fast local lookup for top merchant
    func getTopMerchantName() -> String? {
        // Reuse getUniqueMerchants logic but just take the first one
        // This is fast enough (in-memory)
        return getUniqueMerchants().first
    }
    
    // Get all unique normalized item names for dropdowns
    func getUniqueNormalizedItemNames() -> [String] {
        let names = allLineItems.compactMap { $0.normalizedName }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    func computeMerchantSummary(merchantName: String) -> MerchantSummary? {
        let target = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Helper for hyper-resilient matching
        let canonical: (String) -> String = { str in
            str.lowercased().filter { $0.isLetter || $0.isNumber }
        }
        let targetCanonical = canonical(target)
        
        // 1. Try Exact match first (standardized)
        var filteredItems = allLineItems.filter { 
            ($0.merchantName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
        }
        
        // 2. Fallback to Fuzzy match if exact fails
        if filteredItems.isEmpty {
            filteredItems = allLineItems.filter { item in
                let name = (item.merchantName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return name.contains(target) || target.contains(name)
            }
        }
        
        // 3. NUCLEAR: Canonical match (ignore spaces/symbols)
        if filteredItems.isEmpty && !targetCanonical.isEmpty {
            filteredItems = allLineItems.filter { item in
                canonical(item.merchantName ?? "") == targetCanonical
            }
        }
        
        if filteredItems.isEmpty {
            let available = Array(Set(allLineItems.compactMap { $0.merchantName })).sorted()
            print("❌ DEBUG AnalyticsManager: Lookup failed for [\(target)]. allItemsCount: \(allLineItems.count)")
            print("❌ DEBUG Available (top 10): \(available.prefix(10))")
            
            // Try one last thing: if target is "Other" or empty, match anything with "Other"
            if target == "other" || target.isEmpty {
                filteredItems = allLineItems.filter { ($0.merchantName ?? "Other").lowercased() == "other" }
            }
        } else {
            print("✅ DEBUG AnalyticsManager: Matched [\(target)]. Found \(filteredItems.count) items.")
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
        
        // Lookup Domain
        let domain = getDomain(for: merchantName)
        
        return MerchantSummary(
            merchant: merchantName,
            domain: domain,
            category: storeCat ?? topCat ?? "General",
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
