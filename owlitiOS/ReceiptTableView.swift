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
    var onDelete: (() -> Void)? = nil // Added delete action
    var onEditItem: ((LineItem) -> Void)? = nil
    var onDeleteItem: ((LineItem) -> Void)? = nil
    var isDarkMode: Bool = true
    
    // Adaptive Colors (Matching RecentReceiptRow)
    @Environment(\.colorScheme) var colorScheme
    // Use FDFCFA (Creamy) for Light Mode or 1C1C1E for Dark Mode
    private var containerBg: Color { colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "FDFCFA") }
    private var primaryText: Color { colorScheme == .dark ? Color.white : Color.black }
    private var secondaryText: Color { colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6) }
    private var dividerTint: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1) }
    private var iconBg: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05) }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Merchant Header (No Grid)
            VStack(spacing: 4) {
                if let merchant = data.merchantName {
                    HStack(spacing: 8) {
                        // Merchant Logo
                         AsyncImage(url: URL(string: "https://img.logo.dev/\(cleanDomain(merchant))?token=pk_Sa5pkb0QQ3CfQPaZgFE7jA&size=60&retina=true")) { phase in
                             if let image = phase.image {
                                 image.resizable().aspectRatio(contentMode: .fit)
                             } else if phase.error != nil || merchant.isEmpty {
                                 ZStack {
                                     Circle().fill(Color.gray.opacity(0.1))
                                     Text(merchant.prefix(1).uppercased())
                                         .font(.custom("FKGroteskTrial-Bold", size: 10))
                                         .foregroundColor(primaryText)
                                 }
                             } else {
                                 Color.clear
                             }
                         }
                         .frame(width: 20, height: 20)
                         .background(iconBg)
                         .clipShape(Circle())
                        
                        Text(merchant.uppercased())
                            .font(.custom("FKGroteskTrial-Bold", size: 14))
                            .foregroundColor(primaryText)
                            .tracking(1)
                    }
                }
                
                if let date = data.transactionDate {
                    Text(date)
                        .font(.custom("BerkeleyMono-Regular", size: 11))
                        .foregroundColor(.gray)
                }
                
                // Potential Duplicate Badge
                if data.isPotentialDuplicate == true {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("Duplicate?")
                            .font(.custom("FKGroteskTrial-Medium", size: 10))
                    }
                    .foregroundColor(Color.blue)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            // No background here, letting main container background handle it
            .overlay(
                HStack(spacing: 16) {
                    Button(action: { onEdit?() }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    
                    Button(action: { onDelete?() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
                .padding(.trailing, 12),
                alignment: .trailing
            )
            
            Divider().background(dividerTint)
            
            // MARK: - Items List (With Grid)
            VStack(spacing: 0) {
                // Table Header
                HStack(spacing: 0) {
                    Text("Item").frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                    
                    Rectangle().fill(dividerTint).frame(width: 1, height: 12).cornerRadius(0.5)
                    
                    Text("Qty").frame(width: 40, alignment: .center)
                    
                    Rectangle().fill(dividerTint).frame(width: 1, height: 12).cornerRadius(0.5)
                    
                    Text("Price").frame(width: 70, alignment: .trailing)
                        .padding(.trailing, 12)
                    
                    Spacer().frame(width: 44) // Space for Actions
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .padding(.vertical, 8)
                // Removed extra trailing padding to align with Row's Actions block (44w) exactly.
                // Row: [Content][Actions(44)]
                // Header: [Content][Spacer(44)]
                // Both inside container with no horizontal padding.
                // The Row has internal padding structure. The Header needs to match explicitly.
                // Row has no outer horizontal padding on the Hstack, just internal paddings.
                // The Container has padding(.top, 4).
                // Lets remove extra padding(.leading, 12) etc from text and put it on columns to match row EXACTLY.
                // Actually the current padding on Text is fine if Row matches.
                
                Divider().background(dividerTint)
                
                // Rows
                ForEach(data.lineItems) { item in
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top, spacing: 6) {
                                Text(item.item)
                                    .font(.custom("FKGroteskTrial-Regular", size: 13))
                                    .foregroundColor(primaryText)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer(minLength: 0) // Push pencil to right for vertical alignment
                                
                                Button(action: { onEditItem?(item) }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 10, weight: .bold)) // Smaller, bold pencil
                                        .foregroundColor(primaryText.opacity(0.4)) // Subtle
                                }
                                .buttonStyle(.plain) // Ensure it doesn't hijack row selection if any
                                .padding(.top, 2) // Visually align with text cap height
                                .padding(.trailing, 8) // Prevent touching the divider
                            }
                            
                            // Category / Subcategory
                            HStack(spacing: 4) {
                                if let main = item.mainCategory, !main.isEmpty {
                                    Text(main.capitalized)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(iconBg)
                                        .cornerRadius(4)
                                }
                                
                                if let sub = item.subCategory, !sub.isEmpty {
                                    Text(sub.capitalized)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(dividerTint)
                                        .cornerRadius(4)
                                }
                            }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(primaryText.opacity(0.9))
                            .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                        .padding(.vertical, 10)
                        
                        // Single Dash Separation
                        Rectangle().fill(dividerTint).frame(width: 1, height: 12).cornerRadius(0.5)
                            .padding(.top, 14) // Align with first line of text area (10 padding + approx 4 offset)
                        
                        Text("\(item.quantity ?? 1)")
                            .font(.custom("BerkeleyMono-Regular", size: 13))
                            .foregroundColor(.gray)
                            .frame(width: 40, alignment: .center)
                            .padding(.top, 12)
                        
                        Rectangle().fill(dividerTint).frame(width: 1, height: 12).cornerRadius(0.5)
                            .padding(.top, 14)
                        
                        Text(String(format: "%.2f", item.price ?? 0.0))
                            .font(.custom("BerkeleyMono-Regular", size: 13))
                            .foregroundColor(primaryText)
                            .frame(width: 70, alignment: .trailing)
                            .padding(.trailing, 12)
                            .padding(.top, 12)
                        
                        // Delete Action (End)
                        // Pencil moved to Item Name
                        Button(action: { onDeleteItem?(item) }) {
                             Image(systemName: "trash")
                                 .font(.system(size: 12))
                                 .foregroundColor(Color.red.opacity(0.7))
                        }
                        .padding(.leading, 8)
                        .padding(.top, 10)
                        .frame(width: 44) // Kept width 44 for alignment with Header Spacer
                    }
                    // .padding(.vertical, 10) // Moved inside
                    // .padding(.leading, 12) // Moved inside
                    // .padding(.trailing, 24) // Handled by fixed widths
                    
                    if item.id != data.lineItems.last?.id {
                         Divider().background(dividerTint)
                    }
                }
                
                Divider().background(dividerTint)
                
                // Footer Total
                HStack {
                    Text("Total")
                        .font(.custom("FKGroteskTrial-Bold", size: 13))
                        .foregroundColor(primaryText)
                    Spacer()
                    Text(String(format: "£%.2f", data.totalAmount ?? 0.0))
                        .foregroundColor(Color(hex: "27A565"))
                }
                .padding(12)
                .background(dividerTint.opacity(0.5))
            }
            .background(Color.clear) // Transparent so main container bg shows
        }
        .padding(.top, 4) // Slight top padding for header
        .background(
            ZStack {
                containerBg
                MeshGrid(spacing: 3)
                    .stroke(Color.gray.opacity(0.07), lineWidth: 0.5)
            }
        )
        .cornerRadius(12)
        // Clean look: Just the background color, no stroke or mesh needed if matching RecentReceiptRow simple style.
        // If stroke is desired for separation:
        // .overlay(RoundedRectangle(cornerRadius: 12).stroke(dividerTint, lineWidth: 0.5))
    }

    
    // Helper
    private func cleanDomain(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("co-op") || lower.contains("coop") {
            return "coop.co.uk"
        }
        if lower.contains("waitrose") { return "waitrose.com" } // explicit safety
        
        let simple = lower.filter { $0.isLetter || $0.isNumber }
        return simple + ".com"
    }
}
