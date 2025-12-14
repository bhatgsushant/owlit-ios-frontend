//
//  ReceiptLineItemsTableView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI

struct ReceiptLineItemsTableView: View {
    let receipt: ReceiptRecord
    @State private var animate: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section - Store Name and Total Amount
            VStack(alignment: .leading, spacing: 8) {
                Text(receipt.merchantName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(receipt.totalAmount, format: .currency(code: "USD"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 20)
            
            // Line Items List
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
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
        .opacity(animate ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animate = true
            }
        }
    }
}


// Preview
#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 20) {
                ReceiptLineItemsTableView(
                    receipt: ReceiptRecord(
                        id: "1",
                        merchantName: "FreshMart",
                        transactionDate: Date(),
                        totalAmount: 82.45,
                        lineItems: [
                            ReceiptLineItem(
                                name: "Honeycrisp Apples",
                                quantity: 4,
                                price: 7.96,
                                category: .fruit,
                                subCategory: "Organic"
                            ),
                            ReceiptLineItem(
                                name: "Cold Brew Concentrate",
                                quantity: 1,
                                price: 11.5,
                                category: .beverages,
                                subCategory: "Coffee"
                            ),
                            ReceiptLineItem(
                                name: "Organic Greek Yogurt",
                                quantity: 2,
                                price: 9.0,
                                category: .dairy,
                                subCategory: "Greek"
                            ),
                            ReceiptLineItem(
                                name: "Whole Grain Bread",
                                quantity: 1,
                                price: 4.99,
                                category: .bakery,
                                subCategory: nil
                            )
                        ],
                        storeType: "Grocery",
                        mainCategory: .fruit
                    )
                )
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
    }
}

