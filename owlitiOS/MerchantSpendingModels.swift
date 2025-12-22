import Foundation

struct MerchantSummary: Codable {
    let merchant: String
    let category: String
    let periodStats: PeriodStats
    let trendGraph: [Double?] // Handle explicit nulls (NaN)
    let insights: SpendingInsights
    
    // Helper to get clean graph data
    var cleanTrendGraph: [Double] {
        return trendGraph.compactMap { $0 }
    }
    
    enum CodingKeys: String, CodingKey {
        case merchant
        case category
        case periodStats = "period_stats"
        case trendGraph = "trend_graph"
        case insights
    }
}

struct PeriodStats: Codable {
    let currentMonth: StatDetail
    let currentYear: StatDetail
    let previousMonth: StatDetail
    
    enum CodingKeys: String, CodingKey {
        case currentMonth = "current_month"
        case currentYear = "current_year"
        case previousMonth = "previous_month"
    }
}

struct StatDetail: Codable {
    let total: Double? // Make Optional to prevent crash
    let percentageChange: Double?
    
    var cleanTotal: Double { return total ?? 0.0 }
    
    enum CodingKeys: String, CodingKey {
        case total
        case percentageChange = "percentage_change"
    }
}

struct SpendingInsights: Codable {
    let topCategory: String? // Optional safety
    let topItem: String?     // Optional safety
    let healthScore: HealthScore
    let contributionPercentage: Double? // New: % of total spend
    let visitCount: Int?      // New: Number of visits
    
    enum CodingKeys: String, CodingKey {
        case topCategory = "top_category"
        case topItem = "top_item"
        case healthScore = "health_score"
        case contributionPercentage = "contribution_percentage"
        case visitCount = "visit_count"
    }
}

struct HealthScore: Codable {
    let healthyPercentage: Int
    let unhealthyPercentage: Int
    
    enum CodingKeys: String, CodingKey {
        case healthyPercentage = "healthy_percentage"
        case unhealthyPercentage = "unhealthy_percentage"
    }
}
