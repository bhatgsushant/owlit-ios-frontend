//
//  ReceiptModels.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 14/11/2025.
//

import Foundation

// MARK: - Scan Response
struct ScanResponse: Codable {
    // This might be a wrapper or direct ReceiptData. 
    // Based on ScanReceipt.jsx, it seems to return the data directly.
    // We will assume it returns `ReceiptData`.
}

// MARK: - Receipt Data
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case merchantName = "merchant_name"
        case transactionDate = "transaction_date"
        case totalAmount = "total_amount"
        case storeType = "store_type"
        case lineItems = "line_items"
        case selectedMerchantId // JS uses same casing usually, need to check if snake_case
        case canonicalMerchantId = "canonical_merchant_id"
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
    var price: Double? // Can be string in JS, but we want Double
    var quantity: Int?
    var mainCategory: String?
    var subCategory: String?
    
    // Handling price potentially coming as string or number from raw JSON
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.item = try container.decodeIfPresent(String.self, forKey: .item) ?? ""
        self.quantity = try container.decodeIfPresent(Int.self, forKey: .quantity)
        self.mainCategory = try container.decodeIfPresent(String.self, forKey: .mainCategory)
        self.subCategory = try container.decodeIfPresent(String.self, forKey: .subCategory)
        
        // Handle Price leniently
        if let doublePrice = try? container.decode(Double.self, forKey: .price) {
            self.price = doublePrice
        } else if let stringPrice = try? container.decode(String.self, forKey: .price) {
            // Remove currency symbols and parse
            let clean = stringPrice.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            self.price = Double(clean)
        } else {
            self.price = 0.0
        }
    }
    
    // Default Init
    init(item: String, price: Double?, quantity: Int?, mainCategory: String?, subCategory: String?) {
        self.item = item
        self.price = price
        self.quantity = quantity
        self.mainCategory = mainCategory
        self.subCategory = subCategory
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(item, forKey: .item)
        try container.encode(price, forKey: .price)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(mainCategory, forKey: .mainCategory)
        try container.encode(subCategory, forKey: .subCategory)
    }
    
    enum CodingKeys: String, CodingKey {
        case item
        case price
        case quantity
        case mainCategory = "main_category"
        case subCategory = "sub_category"
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
