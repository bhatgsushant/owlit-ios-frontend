import SwiftUI

struct RecentReceiptRow: View {
    let receipt: ReceiptData
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    private var primaryText: Color { colorScheme == .dark ? Color.white : Color.black }
    private var secondaryText: Color { colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6) }
    private var dividerTint: Color { colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1) }
    private let logoDevToken = "pk_Sa5pkb0QQ3CfQPaZgFE7jA"

    var body: some View {
        HStack(spacing: 12) {
            // 1. Logo
            logoView
            
            // 2. Info (Name + Date)
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchantName ?? "Unknown Merchant")
                    .font(.custom("FKGroteskTrial-Bold", size: 14))
                    .foregroundColor(primaryText)
                    .lineLimit(1)
                
                Text(formatDateStr(receipt.transactionDate))
                    .font(.custom("FKGroteskTrial-Regular", size: 12))
                    .foregroundColor(secondaryText)
            }
            
            Spacer()
            
            Rectangle()
                .fill(dividerTint)
                .frame(width: 1, height: 24)
            
            // 3. Total
            Text(formatCurrency(receipt.totalAmount ?? 0))
                .font(.custom("FKGroteskTrial-Bold", size: 14))
                .foregroundColor(primaryText)
                .padding(.horizontal, 4)
            
            Rectangle()
                .fill(dividerTint)
                .frame(width: 1, height: 24)
            
            // 4. Actions
            HStack(spacing: 16) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue.opacity(0.8))
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7")) // Adaptive Background
        .cornerRadius(12)
    }
    
    // MARK: - Logo View
    private var logoView: some View {
        let domain = AnalyticsManager.shared.getDomain(for: receipt.merchantName ?? "")
        let name = receipt.merchantName ?? "?"
        let url = getLogoUrl(domain: domain, name: name)
        
        return SimpleCachedImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(Circle())
        } placeholder: {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                
                Text(String(name.prefix(1)).uppercased())
                    .font(.custom("FKGroteskTrial-Bold", size: 16))
                    .foregroundColor(secondaryText)
            }
        }
        .frame(width: 40, height: 40)
        .overlay(Circle().stroke(dividerTint, lineWidth: 1))
    }
    
    // MARK: - Helpers
    private func getLogoUrl(domain: String?, name: String) -> URL? {
        let cleanName = name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "-", with: "")
            
        var host = domain ?? "\(cleanName).com"
        
        if let url = URL(string: host), let scheme = url.scheme {
            host = host.replacingOccurrences(of: "\(scheme)://", with: "")
        }
        host = host.replacingOccurrences(of: "www.", with: "")
        if host.hasSuffix("/") { host.removeLast() }
        
        let urlString = "https://img.logo.dev/\(host)?token=\(logoDevToken)&size=100&format=png" + (colorScheme == .dark ? "&greyscale=true" : "")
        return URL(string: urlString)
    }
    
    private func formatDateStr(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            let displayForm = DateFormatter()
            displayForm.dateFormat = "MMM d"
            return displayForm.string(from: date)
        }
        return dateStr
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "£\(amount)"
    }
}
