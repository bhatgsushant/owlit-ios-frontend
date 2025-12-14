import Foundation
import SwiftUI

enum ReceiptCategory: String, CaseIterable, Identifiable, Codable {
    case fruit = "Fruit"
    case vegetable = "Vegetable"
    case meat = "Meat"
    case poultry = "Poultry"
    case seafood = "Seafood"
    case dairy = "Dairy"
    case bakery = "Bakery"
    case beverages = "Beverages"
    case snacks = "Snacks"
    case frozen = "Frozen"
    case cannedGoods = "Canned Goods"
    case personalCare = "Personal Care"
    case health = "Health"
    case fitness = "Fitness"
    case household = "Household"
    case electronics = "Electronics"
    case utilities = "Utilities"
    case clothing = "Clothing"
    case jewelry = "Jewelry"
    case transport = "Transport"
    case travel = "Travel"
    case stationery = "Stationery"
    case education = "Education"
    case finance = "Finance"
    case entertainment = "Entertainment"
    case pets = "Pets"
    case gifts = "Gifts"
    case dining = "Dining"
    case other = "Other"

    var id: String { rawValue }

    var apiValue: String {
        switch self {
        case .cannedGoods: return "canned_goods"
        case .personalCare: return "personal_care"
        default:
            return rawValue
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")
        }
    }

    init(apiValue: String?) {
        guard let apiValue else {
            self = .other
            return
        }
        let normalized = apiValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        if let match = ReceiptCategory.allCases.first(where: { $0.apiValue == normalized }) {
            self = match
        } else {
            self = .other
        }
    }

    var color: Color {
        switch self {
        case .fruit: return Color(red: 0.03, green: 0.54, blue: 0.36)
        case .vegetable: return Color(red: 0.21, green: 0.65, blue: 0.43)
        case .meat: return Color(red: 0.76, green: 0.24, blue: 0.32)
        case .poultry: return Color(red: 0.85, green: 0.46, blue: 0.33)
        case .seafood: return Color(red: 0.33, green: 0.64, blue: 0.89)
        case .bakery: return Color(red: 0.84, green: 0.62, blue: 0.4)
        case .beverages: return Color(red: 0.38, green: 0.63, blue: 0.87)
        case .snacks: return Color(red: 0.97, green: 0.45, blue: 0.41)
        case .frozen: return Color(red: 0.41, green: 0.76, blue: 0.98)
        case .cannedGoods: return Color(red: 0.94, green: 0.67, blue: 0.26)
        case .personalCare: return Color(red: 0.95, green: 0.6, blue: 0.74)
        case .health: return Color(red: 0.8, green: 0.38, blue: 0.38)
        case .fitness: return Color(red: 0.45, green: 0.73, blue: 0.98)
        case .electronics: return Color(red: 0.46, green: 0.63, blue: 0.92)
        case .utilities: return Color(red: 0.2, green: 0.44, blue: 0.87)
        case .clothing: return Color(red: 0.97, green: 0.59, blue: 0.54)
        case .jewelry: return Color(red: 0.96, green: 0.75, blue: 0.36)
        case .transport: return Color(red: 0.29, green: 0.57, blue: 0.82)
        case .travel: return Color(red: 0.99, green: 0.72, blue: 0.4)
        case .stationery: return Color(red: 0.64, green: 0.78, blue: 0.97)
        case .education: return Color(red: 0.66, green: 0.6, blue: 0.97)
        case .finance: return Color(red: 0.99, green: 0.89, blue: 0.38)
        case .entertainment: return Color(red: 0.94, green: 0.5, blue: 0.86)
        case .pets: return Color(red: 0.81, green: 0.54, blue: 0.39)
        case .gifts: return Color(red: 0.97, green: 0.56, blue: 0.56)
        case .dining: return Color(red: 0.54, green: 0.35, blue: 0.87)
        case .dairy: return Color(red: 0.98, green: 0.82, blue: 0.53)
        case .household: return Color(red: 0.69, green: 0.5, blue: 0.87)
        case .other: return Color(red: 0.58, green: 0.63, blue: 0.68)
        }
    }
}

struct ReceiptLineItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var quantity: Double
    var price: Double
    var category: ReceiptCategory
    var subCategory: String?
    var confidence: Double?

    enum CodingKeys: String, CodingKey {
        case item
        case name
        case displayName = "Item_Name"
        case quantity
        case quantityAlt = "Quantity"
        case price
        case priceAlt = "Price"
        case mainCategory = "main_category"
        case subCategory = "sub_category"
        case confidence = "ai_confidence"
    }

    init(name: String, quantity: Double, price: Double, category: ReceiptCategory, subCategory: String? = nil, confidence: Double? = nil) {
        self.name = name
        self.quantity = quantity
        self.price = price
        self.category = category
        self.subCategory = subCategory
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawName = try container.decodeIfPresent(String.self, forKey: .item)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? "Unnamed Item"
        name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        let rawQuantity = try container.decodeIfPresent(Double.self, forKey: .quantity)
            ?? container.decodeIfPresent(Double.self, forKey: .quantityAlt)
            ?? 1
        quantity = rawQuantity > 0 ? rawQuantity : 1

        let rawPrice = try container.decodeIfPresent(Double.self, forKey: .price)
            ?? container.decodeIfPresent(Double.self, forKey: .priceAlt)
            ?? 0
        price = max(0, rawPrice)

        let rawCategory = try container.decodeIfPresent(String.self, forKey: .mainCategory)
        category = ReceiptCategory(apiValue: rawCategory)
        subCategory = try container.decodeIfPresent(String.self, forKey: .subCategory)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .item)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(price, forKey: .price)
        try container.encode(category.apiValue, forKey: .mainCategory)
        try container.encodeIfPresent(subCategory, forKey: .subCategory)
        try container.encodeIfPresent(confidence, forKey: .confidence)
    }

    var formattedPrice: String {
        price.formatted(.currency(code: "USD"))
    }

    var needsReview: Bool {
        guard let confidence else { return false }
        return confidence < 0.85
    }
}

struct ReceiptDraft: Identifiable, Hashable, Codable {
    var id = UUID()
    var merchantName: String
    var location: String?
    var transactionDate: Date
    var subtotal: Double
    var tax: Double
    var lineItems: [ReceiptLineItem]
    var mainCategory: ReceiptCategory
    var storeType: String?
    var receiptId: String?
    var canonicalMerchantId: String?

    enum CodingKeys: String, CodingKey {
        case merchantName = "merchant_name"
        case transactionDate = "transaction_date"
        case totalAmount = "total_amount"
        case tax = "tax_amount"
        case lineItems = "line_items"
        case mainCategory = "main_category"
        case storeType = "store_type"
        case receiptId = "id"
        case canonicalMerchantId = "canonical_merchant_id"
    }

    init(merchantName: String, location: String? = nil, transactionDate: Date, subtotal: Double, tax: Double, lineItems: [ReceiptLineItem], mainCategory: ReceiptCategory, storeType: String? = nil, receiptId: String? = nil) {
        self.merchantName = merchantName
        self.location = location
        self.transactionDate = transactionDate
        self.subtotal = subtotal
        self.tax = tax
        self.lineItems = lineItems
        self.mainCategory = mainCategory
        self.storeType = storeType
        self.receiptId = receiptId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        merchantName = try container.decodeIfPresent(String.self, forKey: .merchantName) ?? ""
        let dateString = try container.decodeIfPresent(String.self, forKey: .transactionDate) ?? Self.serverFormatter.string(from: Date())
        transactionDate = Self.serverFormatter.date(from: dateString) ?? Date()
        let totalAmount = try container.decodeIfPresent(Double.self, forKey: .totalAmount) ?? 0
        tax = try container.decodeIfPresent(Double.self, forKey: .tax) ?? 0
        subtotal = max(0, totalAmount - tax)
        lineItems = try container.decodeIfPresent([ReceiptLineItem].self, forKey: .lineItems) ?? []
        let rawCategory = try container.decodeIfPresent(String.self, forKey: .mainCategory)
        mainCategory = ReceiptCategory(apiValue: rawCategory)
        storeType = try container.decodeIfPresent(String.self, forKey: .storeType)
        receiptId = try container.decodeIfPresent(String.self, forKey: .receiptId)
        canonicalMerchantId = try container.decodeIfPresent(String.self, forKey: .canonicalMerchantId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(merchantName, forKey: .merchantName)
        try container.encode(Self.serverFormatter.string(from: transactionDate), forKey: .transactionDate)
        try container.encode(totalAmount, forKey: .totalAmount)
        try container.encode(tax, forKey: .tax)
        try container.encode(lineItems, forKey: .lineItems)
        try container.encode(mainCategory.apiValue, forKey: .mainCategory)
        try container.encodeIfPresent(storeType, forKey: .storeType)
        try container.encodeIfPresent(receiptId, forKey: .receiptId)
        try container.encodeIfPresent(canonicalMerchantId, forKey: .canonicalMerchantId)
    }

    var lineItemsTotal: Double {
        let sum = lineItems.reduce(0) { partial, item in
            partial + (item.price * max(1, item.quantity))
        }
        return sum
    }

    var totalAmount: Double {
        let base = lineItems.isEmpty ? subtotal : lineItemsTotal
        return max(0, base + tax)
    }

    var formattedDate: String {
        transactionDate.formatted(date: .abbreviated, time: .omitted)
    }

    var locationLabel: String {
        location ?? ""
    }

    func toServerPayload() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static let serverFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let placeholder = ReceiptDraft(
        merchantName: "FreshMart",
        location: "Brooklyn, NY",
        transactionDate: Date(),
        subtotal: 82.45,
        tax: 6.78,
        lineItems: [
            ReceiptLineItem(name: "Honeycrisp Apples", quantity: 4, price: 7.96, category: .fruit, confidence: 0.92),
            ReceiptLineItem(name: "Cold Brew Concentrate", quantity: 1, price: 11.5, category: .beverages, confidence: 0.81),
            ReceiptLineItem(name: "Organic Greek Yogurt", quantity: 2, price: 9.0, category: .dairy, confidence: 0.9)
        ],
        mainCategory: .fruit,
        storeType: "Grocery"
    )
}

struct ReceiptRecord: Identifiable, Codable {
    var id: String
    var merchantName: String
    var transactionDate: Date
    var totalAmount: Double
    var lineItems: [ReceiptLineItem]
    var storeType: String?
    var mainCategory: ReceiptCategory

    enum CodingKeys: String, CodingKey {
        case id
        case merchantName = "merchant_name"
        case transactionDate = "transaction_date"
        case totalAmount = "total_amount"
        case lineItems = "line_items"
        case storeType = "store_type"
        case mainCategory = "main_category"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        merchantName = try container.decodeIfPresent(String.self, forKey: .merchantName) ?? ""
        let dateString = try container.decodeIfPresent(String.self, forKey: .transactionDate) ?? ""
        transactionDate = ReceiptDraft.serverFormatter.date(from: dateString) ?? Date()
        totalAmount = try container.decodeIfPresent(Double.self, forKey: .totalAmount) ?? 0
        lineItems = try container.decodeIfPresent([ReceiptLineItem].self, forKey: .lineItems) ?? []
        storeType = try container.decodeIfPresent(String.self, forKey: .storeType)
        let rawCategory = try container.decodeIfPresent(String.self, forKey: .mainCategory)
        mainCategory = ReceiptCategory(apiValue: rawCategory)
    }

    init(id: String, merchantName: String, transactionDate: Date, totalAmount: Double, lineItems: [ReceiptLineItem], storeType: String?, mainCategory: ReceiptCategory) {
        self.id = id
        self.merchantName = merchantName
        self.transactionDate = transactionDate
        self.totalAmount = totalAmount
        self.lineItems = lineItems
        self.storeType = storeType
        self.mainCategory = mainCategory
    }
}

extension ReceiptRecord {
    init(id: String, draft: ReceiptDraft) {
        self.id = id
        self.merchantName = draft.merchantName
        self.transactionDate = draft.transactionDate
        self.totalAmount = draft.totalAmount
        self.lineItems = draft.lineItems
        self.storeType = draft.storeType
        self.mainCategory = draft.mainCategory
    }
}

struct CategoryAmount: Identifiable, Hashable {
    var id = UUID()
    var category: ReceiptCategory
    var amount: Double
}

extension Array where Element == ReceiptRecord {
    func combinedCategoryTotals() -> [CategoryAmount] {
        var totals: [ReceiptCategory: Double] = [:]
        for receipt in self {
            totals[receipt.mainCategory, default: 0] += receipt.totalAmount
            for item in receipt.lineItems {
                let quantity = item.quantity > 0 ? item.quantity : 1
                totals[item.category, default: 0] += item.price * quantity
            }
        }
        return totals.map { CategoryAmount(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}
