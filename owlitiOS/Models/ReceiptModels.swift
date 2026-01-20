//
//  ReceiptModels.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 14/11/2025.
//

import Foundation
import UIKit

// MARK: - Scan Response
struct ScanResponse: Codable {
    // This might be a wrapper or direct ReceiptData. 
    // Based on ScanReceipt.jsx, it seems to return the data directly.
    // We will assume it returns `ReceiptData`.
}

// MARK: - Receipt Data
// Helper for passing images between views safely
class ImageTransfer {
    static let shared = ImageTransfer()
    var pendingImage: UIImage?
    private init() {}
}

struct ReceiptData: Codable, Identifiable, Equatable {
    var id: String? // Optional, might not exist for new scans
    var merchantName: String?
    var transactionDate: String? // YYYY-MM-DD
    var totalAmount: Double?
    var storeType: String?
    var lineItems: [LineItem]
    
    // Merchant Selection Logic
    var selectedMerchantId: String?

    var canonicalMerchantId: String?
    
    // Duplicate Detection
    var isPotentialDuplicate: Bool?
    
    // Transient - Not Decoded
    var originalImage: UIImage? = nil
    
    var existingReceiptId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case merchantName = "merchant_name"
        case transactionDate = "transaction_date"
        case totalAmount = "total_amount"
        case storeType = "store_type"
        case lineItems = "line_items"
        case existingReceiptId = "existing_receipt_id"
        case selectedMerchantId = "selected_merchant_id"
        case canonicalMerchantId = "canonical_merchant_id"
        case isPotentialDuplicate = "is_potential_duplicate"
    }
    
    init(merchantName: String? = nil, transactionDate: String? = nil, totalAmount: Double? = 0, lineItems: [LineItem] = []) {
        self.merchantName = merchantName
        self.transactionDate = transactionDate
        self.totalAmount = totalAmount
        self.lineItems = lineItems
    }
}

// MARK: - Line Item
struct LineItem: Codable, Identifiable, Equatable {
    var id = UUID() // Local ID for SwiftUI List
    var item: String
    var price: Double?
    var quantity: Int?
    var totalPrice: Double? // Canonical price source
    var mainCategory: String?
    var subCategory: String?
    var transactionDate: String? // YYYY-MM-DD
    
    var normalizedName: String?
    var merchantName: String?
    var storeType: String?
    var receiptId: String?
    var storeMainCategory: String?
    
    // Handling price potentially coming as string or number from raw JSON
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.item = (try? container.decode(String.self, forKey: .item)) ?? ""
        
        // Lenient Quantity
        if let intQty = try? container.decode(Int.self, forKey: .quantity) {
            self.quantity = intQty
        } else if let doubleQty = try? container.decode(Double.self, forKey: .quantity) {
            self.quantity = Int(doubleQty)
        } else if let stringQty = try? container.decode(String.self, forKey: .quantity), let q = Int(stringQty) {
            self.quantity = q
        }
        
        self.mainCategory = try? container.decodeIfPresent(String.self, forKey: .mainCategory)
        self.subCategory = try? container.decodeIfPresent(String.self, forKey: .subCategory)
        self.normalizedName = try? container.decodeIfPresent(String.self, forKey: .normalizedName)
        self.merchantName = try? container.decodeIfPresent(String.self, forKey: .merchantName)
        self.storeType = try? container.decodeIfPresent(String.self, forKey: .storeType)
        self.receiptId = try? container.decodeIfPresent(String.self, forKey: .receiptId)
        self.storeMainCategory = try? container.decodeIfPresent(String.self, forKey: .storeMainCategory)
        self.transactionDate = try? container.decodeIfPresent(String.self, forKey: .transactionDate)
        
        // Handle Price leniently
        if let d = try? container.decode(Double.self, forKey: .price) { self.price = d }
        else if let d = try? container.decode(Double.self, forKey: .unitPrice) { self.price = d }
        else if let s = try? container.decode(String.self, forKey: .price), let d = Double(s.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) { self.price = d }
        else { self.price = 0.0 }
        
        // Handle Total Price
        if let d = try? container.decode(Double.self, forKey: .totalPrice) { self.totalPrice = d }
        else if let s = try? container.decode(String.self, forKey: .totalPrice), let d = Double(s.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) { self.totalPrice = d }
        else if let d = try? container.decode(Double.self, forKey: .totalPriceCamel) { self.totalPrice = d }
        
        // Legacy fallbacks
        if self.mainCategory == nil { self.mainCategory = try? container.decodeIfPresent(String.self, forKey: .mainCategoryCamel) }
        if self.mainCategory == nil { self.mainCategory = try? container.decodeIfPresent(String.self, forKey: .mainCategoryLegacy) }
        if self.subCategory == nil { self.subCategory = try? container.decodeIfPresent(String.self, forKey: .subCategoryCamel) }
        if self.subCategory == nil { self.subCategory = try? container.decodeIfPresent(String.self, forKey: .subCategoryLegacy) }
        
        if self.transactionDate == nil { self.transactionDate = try? container.decodeIfPresent(String.self, forKey: .transactionDate) }
    }
    
    // Default Init
    init(item: String, price: Double?, quantity: Int?, mainCategory: String?, subCategory: String?, totalPrice: Double? = nil, transactionDate: String? = nil, normalizedName: String? = nil, merchantName: String? = nil, storeType: String? = nil, receiptId: String? = nil, storeMainCategory: String? = nil) {
        self.item = item
        self.price = price
        self.quantity = quantity
        self.mainCategory = mainCategory
        self.subCategory = subCategory
        self.totalPrice = totalPrice
        self.transactionDate = transactionDate
        self.normalizedName = normalizedName
        self.merchantName = merchantName
        self.storeType = storeType
        self.receiptId = receiptId
        self.storeMainCategory = storeMainCategory
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(item, forKey: .item)
        try container.encode(price, forKey: .price)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(mainCategory, forKey: .mainCategory)
        try container.encode(subCategory, forKey: .subCategory)
        try container.encode(totalPrice, forKey: .totalPrice)
        try container.encode(normalizedName, forKey: .normalizedName)
        try container.encode(merchantName, forKey: .merchantName)
        try container.encode(storeType, forKey: .storeType)
        try container.encode(receiptId, forKey: .receiptId)
        try container.encode(storeMainCategory, forKey: .storeMainCategory)
    }
    
    enum CodingKeys: String, CodingKey {
        case item
        case price
        case quantity
        case mainCategory = "main_category"
        case mainCategoryCamel = "mainCategory"
        case mainCategoryLegacy = "Category"
        case subCategory = "sub_category"
        case subCategoryCamel = "subCategory"
        case subCategoryLegacy = "SubCategory"
        case totalPrice = "total_price"
        case totalPriceCamel = "totalPrice"
        case transactionDate = "transaction_date"
        case normalizedName = "normalized_name"
        case merchantName = "merchant_name"
        case storeType = "store_type"
        case unitPrice = "unit_price"
        case receiptId = "receipt_id"
        case storeMainCategory = "store_main_category"
    }
}

// MARK: - API Response Models
struct StoreInfo: Codable, Identifiable {
    let id: String
    let merchantName: String
    let storeType: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case merchantName = "merchant_name"
        case storeType = "store_type"
    }
}

struct CategoryOptionsResponse: Codable {
    let userCategories: [CategoryRow]
    let masterCategories: [CategoryRow]
}

struct CategoryRow: Codable {
    let mainCategory: String?
    let subCategory: String?
    
    enum CodingKeys: String, CodingKey {
        case mainCategory = "main_category"
        case subCategory = "sub_category"
    }
}

// MARK: - Merchant Resolution
struct MerchantResolution: Codable, Identifiable {
    let id: String
    let displayName: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct MerchantSummary: Codable {
    let merchant: String
    let domain: String?
    let category: String
    let periodStats: PeriodStats
    let trendGraph: [TrendPoint]?
    
    let insights: SpendingInsights
    
    // Compatibility helper
    var cleanTrendGraph: [Double] { trendGraph?.compactMap { $0.value } ?? [] }
    var safeTrendGraph: [TrendPoint] { trendGraph ?? [] }
    
    enum CodingKeys: String, CodingKey {
        case merchant
        case domain
        case category
        case periodStats = "period_stats"
        case trendGraph = "trend_graph"
        case insights
    }
}

struct TrendPoint: Codable, Identifiable {
    var id: String { date ?? UUID().uuidString }
    let date: String?
    let value: Double?
    
    enum CodingKeys: String, CodingKey {
        case date, value
    }
    
    init(date: String?, value: Double?) {
        self.date = date
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        // Try to decode as object first
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.date = try container.decodeIfPresent(String.self, forKey: .date)
            self.value = try container.decodeIfPresent(Double.self, forKey: .value)
        } else if let singleValue = try? decoder.singleValueContainer() {
            // Fallback: If server sends just a number (backwards compatibility)
            if let doubleVal = try? singleValue.decode(Double.self) {
                self.value = doubleVal
                self.date = nil
            } else if let stringVal = try? singleValue.decode(String.self) {
                self.value = Double(stringVal)
                self.date = nil
            } else {
                self.value = nil
                self.date = nil
            }
        } else {
            self.value = nil
            self.date = nil
        }
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
    let total: Double
    let percentageChange: Double?
    
    var cleanTotal: Double { total }
    
    enum CodingKeys: String, CodingKey {
        case total
        case percentageChange = "percentage_change"
    }
}

struct SpendingInsights: Codable {
    let topCategory: String?
    let topItem: String?
    let healthScore: HealthScore
    let contributionPercentage: Double?
    let visitCount: Int?
    
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


// MARK: - Global Analytics Models

struct AnalyticsOverview: Codable {
    let categories: [AnalyticsCategory]
    let subCategories: [AnalyticsCategory]
    let trend: [AnalyticsTrend]
    let merchants: [AnalyticsCategory]
    let storeTypes: [AnalyticsCategory]
    let items: [AnalyticsItem]
    
    enum CodingKeys: String, CodingKey {
        case categories
        case subCategories = "sub_categories"
        case trend
        case merchants
        case storeTypes = "store_types"
        case items
    }
}

struct AnalyticsCategory: Codable, Identifiable {
    var id: String { label }
    let label: String
    let value: Double
}

struct AnalyticsTrend: Codable, Identifiable {
    var id: String { date }
    let date: String
    let value: Double
}

struct AnalyticsItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let total: Double
    let count: Int
    let avgPrice: Double
    
    enum CodingKeys: String, CodingKey {
        case name
        case total
        case count
        case avgPrice = "avg_price"
    }
}
