//
//  DocumentsView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var receiptStore: ReceiptDataStore

    var body: some View {
        VStack(spacing: 0) {
            CustomNavBar(title: "History", trailingAction: {
                Task { await receiptStore.refresh(using: auth.token) }
            }, trailingIcon: "arrow.clockwise")
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if let error = receiptStore.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.warning)
                            .padding()
                            .background(AppTheme.warning.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Overview Chart
                    SpendOverviewChart(data: receiptStore.receipts.combinedCategoryTotals())
                        .ultraGlass()
                    
                    // List
                    LazyVStack(spacing: 16) {
                        ForEach(receiptStore.receipts) { receipt in
                            ReceiptHistoryCard(receipt: receipt)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .task { await receiptStore.refresh(using: auth.token) }
    }
}

struct SpendOverviewChart: View {
    var data: [CategoryAmount]
    @State private var selectedCategoryID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spend Distribution")
                .font(.headline)
                .foregroundStyle(.white)
            
            Chart(data) { point in
                SectorMark(angle: .value("Amount", point.amount), innerRadius: .ratio(0.6))
                    .foregroundStyle(point.category.color)
                    .cornerRadius(6)
                    .opacity(selectedCategoryID == point.category.rawValue || selectedCategoryID == nil ? 1 : 0.3)
            }
            .frame(height: 200)
            .chartLegend(.hidden)
            .chartAngleSelection(value: $selectedCategoryID)
            .overlay {
                if let selected = data.first(where: { $0.category.rawValue == selectedCategoryID }) ?? data.first {
                    VStack(spacing: 4) {
                        Text(selected.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(selected.amount, format: .currency(code: "USD"))
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(20)
    }
}

struct ReceiptHistoryCard: View {
    var receipt: ReceiptRecord
    @State private var animate: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section - Store Name and Total Amount (like "US" in screenshot)
            VStack(alignment: .leading, spacing: 8) {
                Text(receipt.merchantName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(receipt.totalAmount, format: .currency(code: "USD"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text(receipt.transactionDate, style: .date)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            if !receipt.lineItems.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 20)
                
                // Line Items List (like stock list in screenshot)
                VStack(spacing: 0) {
                    ForEach(Array(receipt.lineItems.enumerated()), id: \.element.id) { index, item in
                        ReceiptLineItemRow(item: item, index: index)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        
                        if index < receipt.lineItems.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.05))
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .ultraGlass()
        .scaleEffect(animate ? 1 : 0.95)
        .opacity(animate ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
}

struct ReceiptLineItemRow: View {
    let item: ReceiptLineItem
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left side - Item name and details (like stock ticker)
            VStack(alignment: .leading, spacing: 8) {
                // Item Name
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Category and Subcategory
                HStack(spacing: 8) {
                    // Category Badge
                    Text(item.category.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.category.color.opacity(0.3))
                        .cornerRadius(6)
                    
                    // Subcategory if available
                    if let subCategory = item.subCategory, !subCategory.isEmpty {
                        Text(subCategory)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                // Quantity and Price info
                HStack(spacing: 12) {
                    if item.quantity > 1 {
                        Label {
                            Text("Qty: \(item.quantity, specifier: "%.1f")")
                                .font(.system(size: 12, weight: .regular))
                        } icon: {
                            Image(systemName: "number")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    Text("Unit: \(item.price, format: .currency(code: "USD"))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Right side - Total Price (like stock price)
            VStack(alignment: .trailing, spacing: 4) {
                let totalPrice = item.price * max(1, item.quantity)
                Text(totalPrice, format: .currency(code: "USD"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                if item.quantity > 1 {
                    Text("\(item.quantity, specifier: "%.1f") × \(item.price, format: .currency(code: "USD"))")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
    }
}
