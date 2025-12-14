//
//  ChatView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI

struct ChatView: View {
    @State private var prompt: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    
    // Custom Colors
    let creamyWhite = Color(hex: "FAF9F6") // Off-white/Cream
    let headerWhite = Color(hex: "FDFDFD").opacity(0.95)
    
    // Quick Replies
    let quickReplies = ["Show Expenses", "Scan Receipt", "Analysis"]

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
        .ignoresSafeArea(.keyboard)
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
    
    private func submitQuery(_ text: String) {
        guard !text.isEmpty else { return }
        
        let userMsg = ChatMessage(content: text, isUser: true)
        withAnimation {
            messages.append(userMsg)
            prompt = ""
            isLoading = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isLoading = false
                let aiResponse = "I have recorded that transaction. 24+42=£ 66?"
                messages.append(ChatMessage(content: aiResponse, isUser: false))
            }
        }
    }
    
    // Date Formatter for "Mono Blank"
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
            
            Text(message.content)
                .font(.custom("FKGroteskTrial-Regular", size: 18)) // Regular for body text
                .foregroundColor(message.isUser ? .black : .black.opacity(0.8))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    message.isUser ? Color(hex: "F3F3F3") : Color.white
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)) // Pill shape
                .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}

#Preview {
    ChatView()
}
