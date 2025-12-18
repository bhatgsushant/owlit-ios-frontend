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
    @State private var editingMessageId: UUID? // Generic ID for message being edited
    
    // Custom Colors
    let pitchBlack = Color(hex: "121212") // Rich Black (Matched from reference)
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
            headerView
            
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
                        
                        if messages.isEmpty {
                            welcomeView
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
                                },
                                onEditReceipt: { data in
                                    // Trigger the sheet with existing data
                                    self.scannedData = data
                                    self.selectedImage = data.originalImage // Might be nil, but View handles it
                                    self.editingMessageId = message.id
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
            ScanReceiptView(image: selectedImage ?? UIImage(), data: data) { savedReceipt in
                // On Success: Update the existing message if we know which one
                if let editingId = editingMessageId,
                   let index = messages.firstIndex(where: { $0.id == editingId }) {
                    
                    // Update In-Place
                    var updatedMsg = messages[index]
                    updatedMsg.receiptData = savedReceipt
                    // Also update content to "Receipt Saved" if it was "Receipt Scanned" or similar? 
                    // User might prefer "Receipt Saved" status.
                    // But typically we just update the data. 
                    // Let's keep content as is or set to "Receipt Saved"
                    // updatedMsg.content = "Receipt Saved" 
                    
                    withAnimation {
                         messages[index] = updatedMsg
                    }
                    self.editingMessageId = nil
                } else {
                    // Fallback (Should not happen in new flow)
                    let summaryMsg = ChatMessage(content: "Receipt Saved", isUser: false, receiptData: savedReceipt)
                    withAnimation {
                        messages.append(summaryMsg)
                    }
                }
            }
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
            "Checking for anomalies..."
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
                            messages[idx] = ChatMessage(id: initialMsg.id, content: nextInsight, isUser: updatedMsg.isUser, timestamp: updatedMsg.timestamp, items: updatedMsg.items, memoryId: updatedMsg.memoryId, suggestedQuestions: updatedMsg.suggestedQuestions, replyingToQuestion: updatedMsg.replyingToQuestion, receiptData: updatedMsg.receiptData, image: updatedMsg.image, isScanning: true)
                        }
                    }
                    index += 1
                }
            }
            
            do {
                let params = ["scanMode": "receipt", "highAccuracy": "false"]
                let (data, _) = try await APIClient.shared.uploadRequest(path: "/api/scan", data: imageData, fileName: "upload.jpg", mimeType: "image/jpeg", parameters: params, token: token)
                var receipt = try JSONDecoder().decode(ReceiptData.self, from: data)
                
                // AUTO-SAVE LOGIC
                // Attempt to save the receipt immediately
                var finalMessage = "Receipt Scanned"
                var saveParams = ["receiptData": ""]
                
                if let jsonData = try? JSONEncoder().encode(receipt),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    saveParams["receiptData"] = jsonString
                }
                
                do {
                    let (saveData, saveResponse) = try await APIClient.shared.uploadRequest(
                        path: "/api/receipts",
                        data: imageData,
                        fileName: "receipt.jpg",
                        fieldName: "receiptImage",
                        mimeType: "image/jpeg",
                        parameters: saveParams,
                        token: token
                    )
                    
                    if let httpResp = saveResponse as? HTTPURLResponse {
                        if httpResp.statusCode == 200 || httpResp.statusCode == 201 {
                            // Success - Saved
                            if let savedR = try? JSONDecoder().decode(ReceiptData.self, from: saveData) {
                                receipt = savedR
                                finalMessage = "Receipt Saved (ID: \(savedR.id ?? "Unknown")).\nTap pencil to edit."
                            } else {
                                finalMessage = "Receipt Saved.\nTap pencil to edit."
                            }
                        } else if httpResp.statusCode == 409 {
                            // Duplicate
                            if let json = try? JSONSerialization.jsonObject(with: saveData) as? [String: Any],
                               let existingId = json["existingReceiptId"] as? String {
                                receipt.id = existingId
                                finalMessage = "Receipt already present (ID: \(existingId)).\nTap pencil to edit."
                            } else {
                                finalMessage = "Receipt already present.\nTap pencil to edit."
                            }
                        } else {
                            // Save Failed
                            print("⚠️ Auto-save failed with status: \(httpResp.statusCode)")
                            // We keep the receipt as scanned but unsaved (or user can retry via edit)
                            finalMessage = "Receipt Scanned (Not Saved)"
                        }
                    }
                } catch {
                    print("⚠️ Auto-save network error: \(error)")
                    // Fallback
                }
                
                await MainActor.run {
                    isFinished = true
                    self.isProcessingImage = false
                    
                    receipt.originalImage = resizedImage // Persist image in transient property
                    
                    if let idx = messages.firstIndex(where: { $0.id == initialMsg.id }) {
                        let old = messages[idx]
                        // Update message IN PLACE with the scanned receipt
                        messages[idx] = ChatMessage(
                            id: initialMsg.id, 
                            content: finalMessage, 
                            isUser: old.isUser, 
                            timestamp: old.timestamp, 
                            items: old.items, 
                            memoryId: old.memoryId, 
                            suggestedQuestions: old.suggestedQuestions, 
                            replyingToQuestion: old.replyingToQuestion, 
                            receiptData: receipt, // Attach receipt data here
                            image: old.image, 
                            isScanning: false
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isFinished = true
                    self.isProcessingImage = false
                     if let idx = messages.firstIndex(where: { $0.id == initialMsg.id }) {
                        let old = messages[idx]
                        messages[idx] = ChatMessage(id: initialMsg.id, content: "Failed to scan", isUser: old.isUser, timestamp: old.timestamp, items: old.items, memoryId: old.memoryId, suggestedQuestions: old.suggestedQuestions, replyingToQuestion: old.replyingToQuestion, receiptData: old.receiptData, image: old.image, isScanning: false)
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
        hideKeyboard() // Dismiss keyboard immediately
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
                        messages.append(ChatMessage(content: aiResponse.answer, isUser: false, items: aiResponse.itemsUsed, memoryId: aiResponse.memoryId, suggestedQuestions: aiResponse.suggestedQuestions, shouldAnimate: true))
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
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Extracted Subviews
extension ChatView {
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left: Back / Sidebar
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal") // Sidebar or Menu? Or Chevron
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                .padding(.leading, 16)
                
                Spacer()
                
                // Title (Logo)
                OwlitLogo(size: 24)
                
                Spacer()
                
                // Right: New Chat
                Button(action: {
                    withAnimation {
                         messages = []
                         isLoading = false
                    }
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white)
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // Divider Removed
        }
        .background(headerBlack)
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            HStack(spacing: 16) {
                OwlitLogo(size: 44)
                    .shadow(color: .white.opacity(0.1), radius: 10)
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
                        .padding(.vertical, 2)
                        .background(Color.white)
                        .cornerRadius(6)
                }
            }
            .padding(.bottom, 40)
            
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
                    .font(.custom("FKGroteskTrial-Medium", size: 16))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .submitLabel(.send)
                
                // 2. Action Row (Below Text)
                HStack(spacing: 2) {
                    // Plus Icon (Attachment Mock)
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    
                    // Camera Icon
                    Button(action: { showCamera = true }) {
                        Image(systemName: "camera")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    
                    // Photo/Gallery Icon
                    Button(action: { showPhotoLibrary = true }) {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    
                    // Manual Entry
                    Button(action: { onManualTap() }) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
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
            .padding(12)
            .background(Color(white: 0.12)) // Dark gray input bg
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(Color.black)
        // Sheets attached here, isolated
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
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
    var onEditReceipt: ((ReceiptData) -> Void)? = nil

    @State private var feedbackGiven: Bool? = nil // nil, true (good), false (bad)
    @State private var isTypingFinished = false
    
    var body: some View {
        VStack(spacing: 0) {
            if message.isUser {
                // USER MESSAGE - Keep as Bubble
                HStack(alignment: .bottom, spacing: 4) {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if let image = message.image {
                             Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        Text(message.content)
                            .font(.custom("FKGroteskTrial-Regular", size: 15))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Receipt Table (Restored for User Bubble)
                        if let receiptData = message.receiptData {
                            ReceiptTableView(data: receiptData) {
                                onEditReceipt?(receiptData)
                            }
                            .frame(width: 280) // Keep width constrained for bubble
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12) // Spacing after user message
                
            } else {
                // AI MESSAGE - Full Width Document Style
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 1. Main Content Text (Full width)
                    if message.receiptData == nil {
                        if message.shouldAnimate {
                            TypewriterText(fullText: message.content, speed: 0.015) {
                                withAnimation {
                                    isTypingFinished = true
                                }
                            }
                        } else {
                            Text(stylizedContent(for: message.content))
                                .font(.custom("FKGroteskTrial-Regular", size: 15)) // Match Suggestions
                                .foregroundColor(.white.opacity(0.95))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .onAppear { isTypingFinished = true }
                        }
                    }
                    
                    // 2. Receipt Data (If any)
                    if let receiptData = message.receiptData {
                        ReceiptTableView(data: receiptData) {
                            onEditReceipt?(receiptData)
                        }
                        .frame(maxWidth: .infinity)
                        // Add a small label if needed, or keep clean
                    }
                    
                    // 3. Action Row (Feedback + Tools)
                    HStack(spacing: 16) {
                        // Feedback
                        HStack(spacing: 0) {
                            Button(action: { 
                                feedbackGiven = true
                                onFeedback?(true) 
                            }) {
                                Image(systemName: "hand.thumbsup")
                                    .font(.system(size: 16))
                                    .foregroundColor(feedbackGiven == true ? .green : .gray)
                                    .padding(8)
                            }
                            
                            Button(action: { 
                                codeFeedback(false) 
                            }) {
                                Image(systemName: "hand.thumbsdown")
                                    .font(.system(size: 16))
                                    .foregroundColor(feedbackGiven == false ? .red : .gray)
                                    .padding(8)
                            }
                        }
                        
                        Spacer()
                        
                        // Mock Tools (Copy, Share) - Visual only for now as requested by style
                        Button(action: {}) {
                            Image(systemName: "square.on.square")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 4)

                    // 4. Vertical Suggestions (Right Aligned Pills)
                    if let suggestions = message.suggestedQuestions, !suggestions.isEmpty {
                        if isTypingFinished || !message.shouldAnimate {
                            VStack(alignment: .trailing, spacing: 12) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button(action: { onSuggestionTap?(suggestion) }) {
                                        Text(suggestion)
                                            .font(.custom("FKGroteskTrial-Regular", size: 15)) // Match User Font
                                            .foregroundStyle(Color.white.opacity(0.9))
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                            .background(Color(white: 0.15)) // Match User Bubble or similar
                                            .clipShape(Capsule()) // Pill Shape
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing) // Force right alignment
                            .padding(.top, 8)
                            .transition(.opacity)
                        }
                    }
                }
                .padding(.horizontal, 16) // Full width minus margin
                .padding(.bottom, 24) // Spacing after AI block
            }
        }
    }
    
    // Helper to fix the feedback closure call in the view body
    func codeFeedback(_ good: Bool) {
        feedbackGiven = good
        onFeedback?(good)
    }
    
    // Text Styler
    func stylizedContent(for text: String) -> AttributedString {
        // 1. Clean up Double Asterisks (Markdown Bold)
        var cleanedText = text.replacingOccurrences(of: "(?m)^\\*\\*\\s?", with: "", options: .regularExpression)
        
        // 2. Replace Numbered Lists (1., 2.) with Bullet Points (●) + Tab
        // Regex: Start of line, digits, dot, space -> replace with Unicode Bullet + Tab
        cleanedText = cleanedText.replacingOccurrences(of: "(?m)^\\d+\\.\\s", with: "●\t", options: .regularExpression)
        
        var attributed = AttributedString(cleanedText)
        
        // 3. Highlight Numbers & Currency (Professional Style)
        do {
            if #available(iOS 16.0, *) {
                // Regex for Currency (optional) + Digits + Decimals
                // Matches: £10.50, $100, 500, 10.5
                let regex = try Regex("[$£€]?[0-9,.]+[0-9]") 
                let matches = cleanedText.matches(of: regex)
                for match in matches {
                    if let range = Range(match.range, in: attributed) {
                        // Apply Bold Monospaced Font
                        attributed[range].font = .system(size: 14, weight: .medium, design: .monospaced)
                        attributed[range].foregroundColor = .white // Ensure high contrast
                    }
                }
            }
        } catch { print("Regex error: \(error)") }
        
        // 4. Apply Paragraph Style (Hanging Indent)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 35 // Indent wrapping lines (statement start position) - Increased for clarity
        paragraphStyle.firstLineHeadIndent = 0 // Bullet starts at 0
        paragraphStyle.paragraphSpacing = 16 // Gap between block paragraphs
        paragraphStyle.paragraphSpacingBefore = 0
        paragraphStyle.lineSpacing = 5 // Moved from View modifier to here to avoid conflict
        
        // Tab Stop for the text after bullet
        let tabStop = NSTextTab(textAlignment: .left, location: 35, options: [:])
        paragraphStyle.tabStops = [tabStop]
        paragraphStyle.defaultTabInterval = 35
        
        attributed.mergeAttributes(AttributeContainer([.paragraphStyle: paragraphStyle]))
        
        return attributed
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
    var receiptData: ReceiptData?
    
    // Receipt Scanning
    var image: UIImage?
    var isScanning: Bool
    
    // Animation State
    var shouldAnimate: Bool

    init(id: UUID = UUID(), 
         content: String, 
         isUser: Bool, 
         timestamp: Date = Date(), 
         items: [SourceItem]? = nil, 
         memoryId: String? = nil, 
         suggestedQuestions: [String]? = nil, 
         replyingToQuestion: String? = nil, 
         receiptData: ReceiptData? = nil,
         image: UIImage? = nil, 
         isScanning: Bool = false,
         shouldAnimate: Bool = false) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.items = items
        self.memoryId = memoryId
        self.suggestedQuestions = suggestedQuestions
        self.replyingToQuestion = replyingToQuestion
        self.receiptData = receiptData
        self.image = image
        self.isScanning = isScanning
        self.shouldAnimate = shouldAnimate
    }
}

// MARK: - Typewriter Text Component
struct TypewriterText: View {
    let fullText: String
    let speed: Double // Seconds per character
    var onComplete: (() -> Void)? = nil
    
    @State private var displayedText: String = ""
    @State private var timer: Timer?
    
    // We need to access the styling function. Since it's in ChatView, we can replicate it or move it out.
    // For simplicity, let's duplicate the styling logic here or pass an attributed string builder closure.
    // Better yet, let's make the styling function static or standalone if possible.
    // Given the constraints, I will copy the styling logic here to ensure it works autonomously.
    
    var body: some View {
        Text(stylizedContent(for: displayedText))
            .font(.custom("FKGroteskTrial-Regular", size: 15))
            .foregroundColor(.white.opacity(0.95))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                startTyping()
            }
            .onChange(of: fullText) { newValue in
                // If text changes (e.g. streaming update), handled differently.
                // For this use case (post-generation typing), we just reset.
                displayedText = ""
                startTyping()
            }
    }
    
    private func startTyping() {
        guard displayedText.count < fullText.count else { return }
        displayedText = ""
        
        // Timer-based typing
        Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { timer in
            if displayedText.count < fullText.count {
                let index = fullText.index(fullText.startIndex, offsetBy: displayedText.count)
                displayedText.append(fullText[index])
                // Haptic feedback for typing feel? Maybe too much.
                // let generator = UIImpactFeedbackGenerator(style: .light)
                // generator.impactOccurred()
            } else {
                timer.invalidate()
                onComplete?()
            }
        }
    }
    
    // Copied Styling Logic (Unified)
    private func stylizedContent(for text: String) -> AttributedString {
        // 1. Clean up Double Asterisks
        var cleanedText = text.replacingOccurrences(of: "(?m)^\\*\\*\\s?", with: "", options: .regularExpression)
        
        // 2. Replace Numbered Lists with Bullet Points + Tab
        cleanedText = cleanedText.replacingOccurrences(of: "(?m)^\\d+\\.\\s", with: "●\t", options: .regularExpression)
        
        var attributed = AttributedString(cleanedText)
        
        // 3. Highlight Numbers & Currency (Professional Style)
        do {
            if #available(iOS 16.0, *) {
                let regex = try Regex("[$£€]?[0-9,.]+[0-9]")
                let matches = cleanedText.matches(of: regex)
                for match in matches {
                    if let range = Range(match.range, in: attributed) {
                        attributed[range].font = .system(size: 15, weight: .bold, design: .monospaced)
                        attributed[range].foregroundColor = .white
                    }
                }
            }
        } catch { print("Regex error: \(error)") }
        
        // 4. Paragraph Style (Hanging Indent)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 35 // Increased Indent
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.paragraphSpacing = 16
        paragraphStyle.paragraphSpacingBefore = 0
        paragraphStyle.lineSpacing = 5 // Internal line spacing
        
        let tabStop = NSTextTab(textAlignment: .left, location: 35, options: [:])
        paragraphStyle.tabStops = [tabStop]
        paragraphStyle.defaultTabInterval = 35
        
        attributed.mergeAttributes(AttributeContainer([.paragraphStyle: paragraphStyle]))
        
        return attributed
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
    var id: UUID = UUID() // Dynamic ID for UI loop
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
    
    // Default Init
    init(itemName: String? = nil, price: Double? = nil, date: String? = nil, merchantName: String? = nil) {
        self.itemName = itemName
        self.price = price
        self.date = date
        self.merchantName = merchantName
    }

    // Robust Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.itemName = try container.decodeIfPresent(String.self, forKey: .itemName)
        self.date = try container.decodeIfPresent(String.self, forKey: .date)
        self.merchantName = try container.decodeIfPresent(String.self, forKey: .merchantName)
        
        // Try decoding price as Double first, then String
        if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .price) {
            self.price = doubleVal
        } else if let stringVal = try? container.decodeIfPresent(String.self, forKey: .price) {
            // "10.50", "£10.50", etc.
            let cleaned = stringVal.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            self.price = Double(cleaned)
        } else {
            self.price = nil
        }
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
