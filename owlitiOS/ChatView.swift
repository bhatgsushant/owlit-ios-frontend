//
//  ChatView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    
    // Receipt Scanning State (Maintained at top level to handle the result)
    @State private var scannedData: ReceiptData?
    @State private var isProcessingImage = false
    @State private var selectedImage: UIImage?
    @State private var isManualEntry = false
    
    // Custom Colors
    let pitchBlack = Color.black
    let headerBlack = Color.black.opacity(0.95)
    
    // Quick Replies
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
                        .foregroundColor(.white)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    // Profile Info
                    // Text("Owlit AI") removed
                    
                    Spacer()
                    
                    Spacer()
                    
                    // Spacer for balance
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                // Separator (Removed as requested)
                // Divider().background(Color.white.opacity(0.2))
            }
            .background(headerBlack)
            
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
                            VStack(spacing: 24) {
                                Spacer(minLength: 60)
                                
                                // Brand Mark Horizontal
                                HStack(spacing: 16) {
                                    OwlitLogo(size: 44)
                                        .shadow(color: .white.opacity(0.1), radius: 10)
                                    
                                    // Vertical Divider
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.5))
                                        .frame(width: 1, height: 36)
                                    
                                    HStack(spacing: 0) {
                                        Text("Hi ")
                                            .font(.custom("FKGroteskTrial-Regular", size: 24))
                                            .foregroundStyle(.white.opacity(0.9))
                                        
                                        Text((authManager.user?.bestDisplayName ?? "User") + " !")
                                            .font(.custom("FKGroteskTrial-Medium", size: 20))
                                            .foregroundStyle(Color.blue)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 2) // Just enough height
                                            .background(Color.white)
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(.bottom, 40) // Increased spacing
                                
                                // Recent Chats / Suggestions
                                if !recentChats.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Recent")
                                            .font(.custom("FKGroteskTrial-Regular", size: 14))
                                            .foregroundStyle(.gray)
                                            .padding(.horizontal, 4)
                                        
                                        ForEach(recentChats) { chat in
                                            Button(action: { submitQuery(chat.title) }) {
                                                HStack {
                                                    Image(systemName: "clock")
                                                        .font(.system(size: 14))
                                                        .foregroundStyle(.gray)
                                                    Text(chat.title)
                                                        .font(.custom("FKGroteskTrial-Regular", size: 15))
                                                        .foregroundStyle(.white.opacity(0.9))
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(.gray.opacity(0.5))
                                                }
                                                .padding(16)
                                                .background(Color(white: 0.1))
                                                .cornerRadius(16)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                                )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 32)
                                } else {
                                    // Fallback to suggestions if no history
                                    FlowLayout(spacing: 8) {
                                        ForEach(quickReplies, id: \.self) { reply in
                                            Button(action: { submitQuery(reply) }) {
                                                Text(reply)
                                                    .font(.custom("FKGroteskTrial-Medium", size: 13))
                                                    .foregroundStyle(.white.opacity(0.9))
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 16)
                                                    .background(Color(white: 0.1))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 20)
                                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                    )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 32)
                                }
                            }
                        }
                        
                        // Messages
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                onFeedback: { isPositive in
                                    sendFeedback(message: message, isPositive: isPositive)
                                },
                                onSuggestionTap: { suggestion in
                                    submitQuery(suggestion)
                                }
                            )
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
                .background(pitchBlack)
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
                }
            }
            
            // MARK: - Input Area (Isolated Subview)
            ChatInputBar(
                onSubmit: { query in submitQuery(query) },
                onImageSelected: { image in handleImageSelection(image) },
                onManualTap: { activateManualMode() }
            )
        }
        .background(pitchBlack)
        .preferredColorScheme(.dark)
        // Sheet for Receipt Review is top level logic
        .sheet(item: $scannedData) { data in
            // For manual entry, we might not have a selectedImage, so we check data presence primary
            // But ScanReceiptView expects an image. We can use a dummy image or nil-handling logic.
            // For now, let's use a placeholder if selectedImage is nil.
            ScanReceiptView(image: selectedImage ?? UIImage(), data: data) 
                .environmentObject(authManager)
        }
        .onAppear { loadRecentChats() }
    }
    
    // Recent Chats State
    @State private var recentChats: [RecentChat] = []
    
    // MARK: - Logic & Handlers
    
    func loadRecentChats() {
        print("🚀 ChatView.onAppear triggered. Checking Auth...")
        if let user = authManager.user {
            print("✅ AuthManager has User: \(user.displayName ?? "No Name")")
        } else {
            print("⚠️ AuthManager User is NIL")
        }
        
        guard let token = authManager.token else { 
            print("❌ No Token in AuthManager")
            return 
        }
        
        Task {
            // Attempt to fetch recent chats. Endpoint assumption: /api/chats
            // If backend doesn't exist yet, this will fail silently and list will be empty
            do {
                print("⏳ Fetching recent chats...")
                let start = Date()
                let (data, _) = try await APIClient.shared.rawRequest(path: "/api/chats", token: token)
                let duration = Date().timeIntervalSince(start)
                print("✅ Fetched chats in \(String(format: "%.2f", duration))s")
                
                let chats = try JSONDecoder().decode([RecentChat].self, from: data)
                await MainActor.run {
                    self.recentChats = Array(chats.prefix(5)) // Show top 5
                }
            } catch {
                print("⚠️ Failed to load chats: \(error)")
                // Fallback to quick replies if fetch fails? Or just empty.
            }
        }
    }
    
    // ... rest of logic
    
    func activateManualMode() {
        isManualEntry = true
        let msg = ChatMessage(content: "Please enter transaction details:\n\nFormat: Qty Item Merchant Price\nExample: 3 Bananas Tesco 1.50", isUser: false)
        withAnimation {
            messages.append(msg)
        }
    }
    
    func handleImageSelection(_ image: UIImage) {
        selectedImage = image
        isProcessingImage = true
        isManualEntry = false // Reset manual mode if image picked
        
        let msgId = UUID()
        let initialMsg = ChatMessage(content: "Analyzing receipt...", isUser: true, image: image, isScanning: true)
        messages.append(initialMsg)
        
        let insights = [
            "Detecting merchant details...",
            "Reading line items...",
            "Calculating total amount...",
            "Categorizing products...",
            "Checking for spending anomalies..."
        ]
        
        // Resize & Upload
        let resizedImage = image.resized(toMaxDimension: 1200)
        
        guard let token = authManager.token,
              let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            isProcessingImage = false
            return
        }
        
        Task {
            // Rotating Insights Simulation
            var isFinished = false
             Task {
                var index = 0
                while !isFinished {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    if isFinished { break }
                    let nextInsight = insights[index % insights.count]
                    await MainActor.run {
                        if let idx = messages.firstIndex(where: { $0.id == initialMsg.id }) {
                            var updatedMsg = messages[idx]
                            messages[idx] = ChatMessage(id: initialMsg.id, content: nextInsight, isUser: updatedMsg.isUser, timestamp: updatedMsg.timestamp, items: updatedMsg.items, memoryId: updatedMsg.memoryId, suggestedQuestions: updatedMsg.suggestedQuestions, replyingToQuestion: updatedMsg.replyingToQuestion, image: updatedMsg.image, isScanning: true)
                        }
                    }
                    index += 1
                }
            }
            
            do {
                let params = ["scanMode": "receipt", "highAccuracy": "false"]
                let (data, _) = try await APIClient.shared.uploadRequest(path: "/api/scan", data: imageData, fileName: "upload.jpg", mimeType: "image/jpeg", parameters: params, token: token)
                let receipt = try JSONDecoder().decode(ReceiptData.self, from: data)
                
                await MainActor.run {
                    isFinished = true
                    self.scannedData = receipt
                    self.isProcessingImage = false
                    
                    if let idx = messages.firstIndex(where: { $0.id == initialMsg.id }) {
                        let old = messages[idx]
                        messages[idx] = ChatMessage(id: initialMsg.id, content: "Receipt Scanned", isUser: old.isUser, timestamp: old.timestamp, items: old.items, memoryId: old.memoryId, suggestedQuestions: old.suggestedQuestions, replyingToQuestion: old.replyingToQuestion, image: old.image, isScanning: false)
                    }
                    messages.append(ChatMessage(content: "Please review the details above.", isUser: false))
                }
            } catch {
                await MainActor.run {
                    isFinished = true
                    self.isProcessingImage = false
                     if let idx = messages.firstIndex(where: { $0.id == initialMsg.id }) {
                        let old = messages[idx]
                        messages[idx] = ChatMessage(id: initialMsg.id, content: "Failed to scan", isUser: old.isUser, timestamp: old.timestamp, items: old.items, memoryId: old.memoryId, suggestedQuestions: old.suggestedQuestions, replyingToQuestion: old.replyingToQuestion, image: old.image, isScanning: false)
                    }
                    messages.append(ChatMessage(content: "❌ Error: \(error.localizedDescription)", isUser: false))
                }
            }
        }
    }
    
    private var typingIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle().fill(Color.gray.opacity(0.4)).frame(width: 6, height: 6)
                    .scaleEffect(isLoading ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: isLoading)
            }
        }
        .padding(12)
        .background(Color(uiColor: .systemGray6))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func submitQuery(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMsg = ChatMessage(content: trimmed, isUser: true)
        withAnimation {
            messages.append(userMsg)
            isLoading = true
        }
        
        // CHECK MANUAL MODE
        if isManualEntry {
             processManualTransaction(trimmed)
             return
        }
        
        Task {
            do {
                let history = messages.dropLast().compactMap { msg -> [String: String]? in
                    return ["role": msg.isUser ? "user" : "ai", "text": msg.content]
                }
                
                let body: [String: Any] = ["question": trimmed, "history": history]
                let bodyData = try JSONSerialization.data(withJSONObject: body)
                
                let (data, _) = try await APIClient.shared.rawRequest(path: "/api/ask-ai", method: "POST", body: bodyData, token: authManager.token)
                let aiResponse = try JSONDecoder().decode(AskAIResponse.self, from: data)
                
                await MainActor.run {
                    withAnimation {
                        isLoading = false
                        messages.append(ChatMessage(content: aiResponse.answer, isUser: false, items: aiResponse.itemsUsed, memoryId: aiResponse.memoryId, suggestedQuestions: aiResponse.suggestedQuestions))
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        isLoading = false
                        messages.append(ChatMessage(content: "Sorry, something went wrong.", isUser: false))
                    }
                }
            }
        }
    }
    
    // MARK: - Manual Processing
    private func processManualTransaction(_ text: String) {
        // We reuse the existing Scan pipeline by converting text to an image.
        // This ensures the backend (AI) handles categorization consistency.
        
        guard let textImage = UIImage.from(text: text) else {
            // Fallback if image creation fails (rare)
            Task {
                await MainActor.run {
                     messages.append(ChatMessage(content: "❌ Failed to process text.", isUser: false))
                }
            }
            return
        }
        
        // Exit manual mode and trigger the standard flow
        isManualEntry = false
        handleImageSelection(textImage)
    }
    

    
    private func sendFeedback(message: ChatMessage, isPositive: Bool) {
        guard let memoryId = message.memoryId else { return }
        let feedbackType = isPositive ? "good" : "bad"
        Task {
            let feedbackBody: [String: Any] = ["question": message.replyingToQuestion ?? "", "answer": message.content, "feedback": feedbackType, "memory_id": memoryId]
            let bodyData = try JSONSerialization.data(withJSONObject: feedbackBody)
            _ = try? await APIClient.shared.rawRequest(path: "/api/feedback", method: "POST", body: bodyData, token: authManager.token)
        }
    }
    
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }
}

// MARK: - Isolated Input Bar View
// This view manages its own state for sheets, preventing re-renders of the main list
struct ChatInputBar: View {
    var onSubmit: (String) -> Void
    var onImageSelected: (UIImage) -> Void
    var onManualTap: () -> Void
    
    @State private var prompt: String = ""
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Text Field Area
                TextField("Ask anything...", text: $prompt)
                    .font(.custom("FKGroteskTrial-Medium", size: 18))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .foregroundColor(.white)
                    .accentColor(.white)
                
                // 2. Action Row (Below Text)
                HStack(spacing: 16) {
                    // Plus Icon (Attachment Mock)
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    // Camera Icon
                    Button(action: { showCamera = true }) {
                        Image(systemName: "camera")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    // Photo/Gallery Icon
                    Button(action: { showPhotoLibrary = true }) {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    // Manual Entry Pencil (NEW)
                    // Manual Entry Pencil
                    Button(action: { onManualTap() }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Send Button
                    Button(action: { 
                        onSubmit(prompt)
                        prompt = ""
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(prompt.isEmpty ? Color.gray.opacity(0.3) : Color.white)
                            .clipShape(Circle())
                    }
                    .disabled(prompt.isEmpty)
                }
            }
            .padding(16)
            .background(Color(white: 0.12)) // Dark gray input bg
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(Color.black)
        // Sheets attached here, isolated
        .sheet(isPresented: $showCamera) {
            DocumentScanner { image in
                onImageSelected(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoPicker { image in
                onImageSelected(image)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    var onFeedback: ((Bool) -> Void)? = nil
    var onSuggestionTap: ((String) -> Void)? = nil
    @State private var feedbackGiven: Bool? = nil // nil, true (good), false (bad)
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 4) {
                if message.isUser {
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Image Display
                    if let image = message.image {
                        VStack(spacing: 8) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit() // Changed to fix aspect ratio
                                .frame(maxWidth: 240) // Limit width but let height adjust
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            if message.isScanning {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white) // White spinner
                                    Text(message.content)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(12)
                                .background(Color(white: 0.15).opacity(0.9)) // Darker background
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Text Content (Only if not scanning or if no image exist, or if we want to show text below image when finished)
                    if message.image == nil || !message.isScanning {
                        Text(message.content)
                            .font(.custom("FKGroteskTrial-Regular", size: 17))
                            .foregroundColor(.white.opacity(0.9)) // White text
                            .fixedSize(horizontal: false, vertical: true) // Ensure multiline wraps
                    }
                    
                    // Feedback Buttons (AI Only)
                    if !message.isUser {
                        HStack(spacing: 8) {
                            Button(action: {
                                feedbackGiven = true
                                onFeedback?(true)
                            }) {
                                HStack(spacing: 4) {
                                    Text("Good")
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "hand.thumbsup")
                                        .font(.system(size: 12))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(feedbackGiven == true ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                                .foregroundColor(feedbackGiven == true ? .green : .gray)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                feedbackGiven = false
                                onFeedback?(false)
                            }) {
                                HStack(spacing: 4) {
                                    Text("Bad")
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "hand.thumbsdown")
                                        .font(.system(size: 12))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(feedbackGiven == false ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                                .foregroundColor(feedbackGiven == false ? .red : .gray)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    message.isUser ? Color(white: 0.15) : Color.black
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: message.isUser ? .trailing : .leading)
                
                if !message.isUser {
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            
            // Suggested Questions (Below AI Bubble)
            if !message.isUser, let suggestions = message.suggestedQuestions, !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: { onSuggestionTap?(suggestion) }) {
                                Text(suggestion)
                                    .font(.system(size: 13, weight: .medium)) // Used system font for consistency with new additions
                                    .foregroundStyle(Color.white.opacity(0.8))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color(white: 0.1))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 32) // Indent slightly more than the bubble
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Helper FlowLayout
// Simple flow layout for tags/chips
// (Kept if needed elsewhere, otherwise safe to keep for now)
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
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    var items: [SourceItem]?
    var memoryId: String?
    var suggestedQuestions: [String]?
    var replyingToQuestion: String?
    
    // Receipt Scanning
    var image: UIImage?
    var isScanning: Bool

    init(id: UUID = UUID(), 
         content: String, 
         isUser: Bool, 
         timestamp: Date = Date(), 
         items: [SourceItem]? = nil, 
         memoryId: String? = nil, 
         suggestedQuestions: [String]? = nil, 
         replyingToQuestion: String? = nil, 
         image: UIImage? = nil, 
         isScanning: Bool = false) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.items = items
        self.memoryId = memoryId
        self.suggestedQuestions = suggestedQuestions
        self.replyingToQuestion = replyingToQuestion
        self.image = image
        self.isScanning = isScanning
    }
}

struct AskAIResponse: Codable {
    let answer: String
    let itemsUsed: [SourceItem]?
    let memoryId: String?
    let suggestedQuestions: [String]?
    
    enum CodingKeys: String, CodingKey {
        case answer
        case itemsUsed = "items_used"
        case memoryId = "memory_id"
        case suggestedQuestions = "suggested_questions"
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

struct RecentChat: Codable, Identifiable {
    let id: String
    let title: String
    let created_at: String?
}

#Preview {
    ChatView()
        .environmentObject(AuthManager())
}
