//
//  ChatView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var prompt: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    
    // Custom Colors
    let creamyWhite = Color(hex: "FAF9F6") // Off-white/Cream
    let headerWhite = Color(hex: "FDFDFD").opacity(0.95)
    
    // Quick Replies (Matching AskAIPage.jsx suggestions)
    let quickReplies = [
        "Spend Summary",
        "Recent Grocery",
        "How much did I spend in Tesco?",
        "Last Receipt"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Back Button
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .foregroundColor(.black)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    // Profile Info
                    Text("Owlit AI")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(.black)
                    
                    Spacer()
                    
                    // Spacer for balance
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                // Separator
                Divider()
            }
            .background(headerWhite)
            
            // MARK: - Chat Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Date Header
                        Text("Today \(currentDateString)")
                            .font(.custom("BerkeleyMono-Regular", size: 11))
                            .foregroundStyle(.gray)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        
                        // Empty State
                        if messages.isEmpty {
                            VStack(spacing: 16) {
                                Spacer(minLength: 50)
                                Text("Where knowledge begins") 
                                    .font(.custom("FKGroteskTrial-Medium", size: 24))
                                    .foregroundStyle(.black.opacity(0.7))
                                
                                // Internal Quick Replies (Optional, if you want them in the empty state like Perplexity)
                                // For now, relying on the keyboard suggestions or sticking to the design requested.
                                // Adding the chips here as per AskAIPage.jsx behavior (suggestions in center)
                                FlowLayout(spacing: 8) {
                                    ForEach(quickReplies, id: \.self) { reply in
                                        Button(action: { submitQuery(reply) }) {
                                            Text(reply)
                                                .font(.custom("FKGroteskTrial-Medium", size: 13))
                                                .foregroundStyle(.black.opacity(0.8))
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 16)
                                                .background(Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                                )
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // Messages
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if isLoading {
                            typingIndicator
                                .padding(.leading, 20)
                                .padding(.top, 4)
                        }
                        
                        // Spacer for input area
                        Color.clear.frame(height: 140).id("BOTTOM")
                    }
                    .padding(.bottom, 16)
                }
                .background(creamyWhite)
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
                }
            }
            
            // MARK: - Input Area (Perplexity Style)
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    // 1. Text Field Area
                    TextField("Ask anything...", text: $prompt)
                        .font(.custom("FKGroteskTrial-Medium", size: 18))
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    
                    // 2. Action Row (Below Text)
                    HStack(spacing: 16) {
                        // Plus Icon
                        Button(action: {}) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        
                        // Camera Icon (Smaller as requested)
                        Button(action: {}) {
                            Image(systemName: "camera")
                                .font(.system(size: 18, weight: .regular)) // Reduced size
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Send Button
                        Button(action: { submitQuery(prompt) }) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(prompt.isEmpty ? Color.gray.opacity(0.3) : Color.black)
                                .clipShape(Circle())
                        }
                        .disabled(prompt.isEmpty)
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .background(creamyWhite.opacity(0.8))
        }
        .background(creamyWhite)
        .preferredColorScheme(.light)
    }
    
    // MARK: - Quick Replies View (No longer used in body)
    private var quickRepliesView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickReplies, id: \.self) { reply in
                    Button(action: { submitQuery(reply) }) {
                        Text(reply)
                            .font(.custom("AvenirNext-Medium", size: 14))
                            .foregroundStyle(.blue)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var typingIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 6, height: 6)
                    .scaleEffect(isLoading ? 1.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(i) * 0.2),
                        value: isLoading
                    )
            }
        }
        .padding(12)
        .background(Color(uiColor: .systemGray6))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Actions
    private func resetChat() {
        withAnimation {
            messages.removeAll()
            prompt = ""
        }
    }
    
    // MARK: - API Call
    private func submitQuery(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMsg = ChatMessage(content: trimmed, isUser: true)
        withAnimation {
            messages.append(userMsg)
            prompt = ""
            isLoading = true
        }
        
        Task {
            do {
                // 1. Prepare Request
                let body: [String: String] = ["question": trimmed]
                let bodyData = try JSONEncoder().encode(body)
                
                // 2. Fetch from API
                let (data, response) = try await APIClient.shared.rawRequest(
                    path: "/api/ask-ai",
                    method: "POST",
                    body: bodyData,
                    token: authManager.token
                )
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "ChatError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get response"])
                }
                
                // 3. Decode
                let aiResponse = try JSONDecoder().decode(AskAIResponse.self, from: data)
                
                // 4. Update UI
                await MainActor.run {
                    withAnimation {
                        isLoading = false
                        let aiMsg = ChatMessage(
                            content: aiResponse.answer,
                            isUser: false,
                            items: aiResponse.itemsUsed
                        )
                        messages.append(aiMsg)
                    }
                }
            } catch {
                print("Ask AI Error: \(error)")
                await MainActor.run {
                    withAnimation {
                        isLoading = false
                        let errorMsg = ChatMessage(content: "Sorry, something went wrong. Please try again.", isUser: false)
                        messages.append(errorMsg)
                    }
                }
            }
        }
    }
    
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Text Content
                Text(message.content)
                    .font(.custom("FKGroteskTrial-Regular", size: 18))
                    .foregroundColor(message.isUser ? .black : .black.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true) // Ensure multiline wraps
                
                // Sources Card (If AI and has items)
                if !message.isUser, let items = message.items, !items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SOURCES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(1) // uppercase tracking
                        
                        ForEach(items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.itemName ?? "Item")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.black)
                                    
                                    HStack(spacing: 6) {
                                        Text("£\(String(format: "%.2f", item.price ?? 0))")
                                            .font(.custom("BerkeleyMono-Regular", size: 11))
                                            .foregroundStyle(.black.opacity(0.8))
                                        
                                        if let merchant = item.merchantName {
                                            Text("• \(merchant)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        if let date = item.date {
                                            Text("• \(date)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                message.isUser ? Color(hex: "F3F3F3") : Color.white
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Helper FlowLayout
// Simple flow layout for tags/chips
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flow(proposal: proposal, subviews: subviews, compute: true)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        flow(proposal: proposal, subviews: subviews, placeIn: bounds)
    }
    
    private func flow(proposal: ProposedViewSize, subviews: Subviews, placeIn bounds: CGRect? = nil, compute: Bool = false) -> (size: CGSize, Void) {
        let maxWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth {
                // New Line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            if let bounds = bounds {
                subview.place(at: CGPoint(x: bounds.minX + currentX, y: bounds.minY + currentY), proposal: .unspecified)
            }
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }
        
        return (CGSize(width: maxX, height: currentY + lineHeight), ())
    }
}


// MARK: - Models
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
    var items: [SourceItem]? = nil // Optional sources
}

struct AskAIResponse: Codable {
    let answer: String
    let itemsUsed: [SourceItem]?
    
    enum CodingKeys: String, CodingKey {
        case answer
        case itemsUsed = "items_used"
    }
}

struct SourceItem: Codable, Identifiable {
    var id: UUID { UUID() } // Dynamic ID for UI loop
    let itemName: String?
    let price: Double?
    let date: String?
    let merchantName: String?
    
    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case price
        case date
        case merchantName = "merchant_name"
    }
}

#Preview {
    ChatView()
        .environmentObject(AuthManager())
}
