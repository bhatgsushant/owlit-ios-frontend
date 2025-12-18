//
//  ReceiptTableView.swift
//  owlitiOS
//
//  Created by Assistant on 17/12/2025.
//

import SwiftUI

struct ReceiptTableView: View {
    let data: ReceiptData
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Receipt Header
            VStack(spacing: 4) {
                if let merchant = data.merchantName {
                    HStack(spacing: 8) {
                        // Merchant Logo
                         AsyncImage(url: URL(string: "https://img.logo.dev/\(cleanDomain(merchant))?token=pk_Sa5pkb0QQ3CfQPaZgFE7jA&size=60&retina=true")) { phase in
                             if let image = phase.image {
                                 image.resizable().aspectRatio(contentMode: .fit)
                             } else if phase.error != nil || merchant.isEmpty {
                                 // Fallback
                                 ZStack {
                                     Circle().fill(Color.gray.opacity(0.1))
                                     Text(merchant.prefix(1).uppercased())
                                         .font(.custom("FKGroteskTrial-Bold", size: 10))
                                         .foregroundColor(.white)
                                 }
                             } else {
                                 // Loading - keep it subtle
                                 Color.clear
                             }
                         }
                         .frame(width: 20, height: 20)
                         .background(Color.white.opacity(0.1))
                         .clipShape(Circle())
                        
                        Text(merchant.uppercased())
                            .font(.custom("FKGroteskTrial-Bold", size: 14))
                            .foregroundColor(.white)
                            .tracking(1) // Letter spacing
                    }
                }
                
                if let date = data.transactionDate {
                    Text(date)
                        .font(.custom("BerkeleyMono-Regular", size: 11))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .overlay(
                Button(action: { onEdit?() }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .contentShape(Rectangle()) // Easier touch target
                }
                .padding(.trailing, 4),
                alignment: .topTrailing
            )
            
            Divider().background(Color.gray.opacity(0.3))
            
            // Header
            HStack {
                Text("Item")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Qty")
                    .frame(width: 30)
                Text("Price")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.gray)
            .padding(.bottom, 8)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider().background(Color.gray.opacity(0.3))
            
            // Rows
            ForEach(data.lineItems) { item in
                HStack(alignment: .top) { // Top alignment for multi-line
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.item)
                            .font(.custom("FKGroteskTrial-Regular", size: 13))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Category / Subcategory
                        HStack(spacing: 4) {
                            if let main = item.mainCategory, !main.isEmpty {
                                Text(main.capitalized)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            if let sub = item.subCategory, !sub.isEmpty {
                                Text(sub.capitalized)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(4)
                            }
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("\(item.quantity ?? 1)")
                        .font(.custom("BerkeleyMono-Regular", size: 13))
                        .foregroundColor(.gray)
                        .frame(width: 30)
                        .padding(.top, 2) // Align with item text
                    
                    Text(String(format: "%.2f", item.price ?? 0.0))
                        .font(.custom("BerkeleyMono-Regular", size: 13))
                        .foregroundColor(.white)
                        .frame(width: 60, alignment: .trailing)
                        .padding(.top, 2)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                
                if item.id != data.lineItems.last?.id {
                     Divider().background(Color.gray.opacity(0.2))
                }
            } // End ForEach
            
            Divider().background(Color.gray.opacity(0.3))
            
            // Footer Total
            HStack {
                Text("Total")
                    .font(.custom("FKGroteskTrial-Bold", size: 13))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "£%.2f", data.totalAmount ?? 0.0))
                    .font(.custom("BerkeleyMono-Regular", size: 14))
                    .foregroundColor(Color(hex: "27A565"))
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
        }
        .background(Color(hex: "111111"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // Helper
    private func cleanDomain(_ name: String) -> String {
        return name.lowercased().filter { $0.isLetter || $0.isNumber } + ".com"
    }
}
