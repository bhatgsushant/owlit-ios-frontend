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
    
    // UI Logic
    @State private var scanningSteps: [String] = []
    @State private var showSuccessPopup = false
    
    // Finance Popup
    @State private var selectedMerchant: String? // For sheet presentation
    
    // Custom Colors
    let pitchBlack = Color.black // Pure Black as requested
    let headerBlack = Color.black.opacity(0.95)
    
    // Quick Replies
    let quickReplies = [
        "Spend Summary",
        "Recent Grocery",
        "How much did I spend in Tesco this month?",
        "Give me breakdown of my categories for this month"
    ]

    var body: some View {
        ZStack {
            ZStack(alignment: .top) {
                // MARK: - Layer 0: Full Screen Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            // Spacer for Header (Dynamic or Fixed?)
                            // Header is approx 50-60pt total? Padding 8+12+24 = 44 + SafeArea.
                            // Let's use a safe spacer 
                            Color.clear.frame(height: 60)
                            
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
                                    },
                                    onAnimationEnd: {
                                        handleAnimationEnd(for: message.id)
                                    },
                                    onMerchantTap: { merchant in
                                        self.selectedMerchant = merchant
                                    }
                                )
                                .id(message.id)
                            }
                            
                            // Scanning Progress moved to floating overlay
                            
                            if isLoading {
                                typingIndicator
                                    .padding(.leading, 20)
                                    .padding(.top, 4)
                            }
                            
                            // Spacer for input area - Increased to avoid hiding behind tab bar
                            Color.clear.frame(height: 160).id("BOTTOM")
                        }
                        .padding(.bottom, 0)
                    }
                    .background(pitchBlack)
                    .ignoresSafeArea() // True Full Screen
                    .onChange(of: messages.count) { _ in
                        withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
                    }
                    .onChange(of: scanningSteps.count) { _ in
                         withAnimation { proxy.scrollTo("SCANNING_PROGRESS", anchor: .bottom) }
                    }
                }
                .zIndex(0)
                .onTapGesture {
                    // Dimiss Keyboard on Tap
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                
                // MARK: - Layer 1: Header Overlay
                headerView
                    .zIndex(2)
                
                // MARK: - Layer 2: Input Bar Overlay
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Specific placement for Scanning Progress: Floating above the bar
                    if !scanningSteps.isEmpty {
                        ScanningProgressView(steps: scanningSteps)
                            .padding(.bottom, 8)
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    ChatInputBar(
                        onSubmit: { query in submitQuery(query) },
                        onImageSelected: { image in handleImageSelection(image) },
                        onManualTap: { toggleManualMode() },
                        isManualMode: isManualEntry
                    )
                    .padding(.bottom, 10) // Lift slightly from edge
                }
                .zIndex(3)
            }
            .blur(radius: showSuccessPopup ? 10 : 0) // Blur main content when popup is active
            .background(pitchBlack)
            .cornerRadius(44)
            .overlay(
                RoundedRectangle(cornerRadius: 44)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .ignoresSafeArea() 
            )
            .ignoresSafeArea(.container, edges: .bottom) // Ensure Edge-to-Edge
            .preferredColorScheme(.dark)
            
            // Success Popup Overlay
            if showSuccessPopup {
                SuccessOverlayView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
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
        // Finance Sheet
        .sheet(item: Binding<String?>(
            get: { selectedMerchant },
            set: { selectedMerchant = $0 }
        )) { merchant in
            FinancialSummaryView(merchant: merchant)
                .environmentObject(authManager)
                .presentationDetents([.fraction(0.6), .medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear { loadRecentChats() }
    }
    
    // ... Subviews Definitions
    
    struct ScanningProgressView: View {
        let steps: [String]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Progress Bar
                // Progress Bar Row with Animated Logo
                HStack(spacing: 12) {
                    OwlitLogo(size: 30, isScanning: true)
                    
                    // Modern Sleek Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Track
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)
                            
                            // Indicator
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: "DFFF00"), Color.green]), // Yellowish-Green to Green
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * (Double(steps.count) / 6.0), height: 6)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: steps.count)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 12) {
                            if index < steps.count - 1 {
                                 Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            
                            Text(step)
                                .font(.custom("FKGroteskTrial-Regular", size: 14))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color(white: 0.15))
                        .clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            }
        }
    }

    struct SuccessOverlayView: View {
        @State private var confettiTrigger = false
        
        var body: some View {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                
                // Confetti
                if confettiTrigger {
                     ConfettiView()
                }
                
                VStack {
                     Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.green) // Green Tick
                        .padding(24)
                        .background(Color(hex: "FF4500")) // Fire Orange Circle
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                withAnimation {
                    confettiTrigger = true
                }
            }
        }
    }
    
    // Simple Confetti
    struct ConfettiView: View {
        @State private var animate = false
        
        var body: some View {
            ZStack {
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill([Color.red, Color.blue, Color.green, Color.orange, Color.purple].randomElement()!)
                        .frame(width: 8, height: 8)
                        .offset(x: animate ? CGFloat.random(in: -200...200) : 0, y: animate ? CGFloat.random(in: -300...300) : 0)
                        .opacity(animate ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).delay(Double.random(in: 0...0.2)), value: animate)
                }
            }
            .onAppear { animate = true }
        }
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
    
    func toggleManualMode() {
        if isManualEntry {
            isManualEntry = false
            // Optional: Remove the last AI message if it was the manual mode prompt to clean up?
            // For now, we just disable the mode so next input is normal.
        } else {
            isManualEntry = true
            let msg = ChatMessage(content: "Please enter transaction details:\n\nFormat: Qty Item Merchant Price\nExample: 3 Bananas Tesco 1.50", isUser: false)
            withAnimation {
                messages.append(msg)
            }
        }
    }
    
    func handleImageSelection(_ image: UIImage) {
        hideKeyboard() // Dismiss keyboard first
        selectedImage = image
        isProcessingImage = true
        isManualEntry = false
        scanningSteps = [] // Reset steps
        
        // Add initial user message (Image Only)
        let userMsg = ChatMessage(content: "", isUser: true, image: image) // Empty content to hide text
        messages.append(userMsg)
        
        // Define steps
        let steps = [
            "Detecting Merchant Details",
            "Reading Line Items",
            "Calculating Total Amount",
            "Categorizing Products",
            "Checking for Anomalies"
        ]
        
        let resizedImage = image.resized(toMaxDimension: 1200)
        
        guard let token = authManager.token,
              let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            isProcessingImage = false
            return
        }
        
        Task {
            // Simulator for Steps
            var isFinished = false
            Task {
                for (index, step) in steps.enumerated() {
                    if isFinished { break }
                    
                    // Add step (shows as loading)
                    await MainActor.run {
                        withAnimation {
                            scanningSteps.append(step)
                        }
                    }
                    
                    // Artificial delay for specific step
                    try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s per step
                    
                    // Keep the step as 'completed' (in this simple strings array, we render last as loading, others as done. Or just show all done.)
                    // User wants: "when completed are ticked in green".
                    // My implementation below handles this via index.
                }
            }
            
            do {
                let params = ["scanMode": "receipt", "highAccuracy": "false"]
                let (data, _) = try await APIClient.shared.uploadRequest(path: "/api/scan", data: imageData, fileName: "upload.jpg", mimeType: "image/jpeg", parameters: params, token: token)
                var receipt = try JSONDecoder().decode(ReceiptData.self, from: data)
                
                // AUTO-SAVE LOGIC
                var finalMessage = "Receipt Scanned"
                var saveParams = ["receiptData": ""]
                
                if let jsonData = try? JSONEncoder().encode(receipt),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    saveParams["receiptData"] = jsonString
                }
                
                // Save...
                _ = try? await APIClient.shared.uploadRequest(path: "/api/receipts", data: imageData, fileName: "receipt.jpg", fieldName: "receiptImage", mimeType: "image/jpeg", parameters: saveParams, token: token)
                
                isFinished = true
                
                await MainActor.run {
                    self.isProcessingImage = false
                    self.scanningSteps = [] // Clear steps (vanish)
                    self.showSuccessPopup = true // Show Success
                    
                    // Delay hiding popup and showing result
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            self.showSuccessPopup = false
                            
                            receipt.originalImage = resizedImage
                            // Add final receipt message
                            messages.append(ChatMessage(
                                content: "Receipt Successfully Saved",
                                isUser: false,
                                receiptData: receipt,
                                style: .success
                            ))
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isFinished = true
                    self.isProcessingImage = false
                    self.scanningSteps = []
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
                let history = messages.dropLast().compactMap { msg -> [String: Any]? in
                    var dict: [String: Any] = [
                        "role": msg.isUser ? "user" : "ai",
                        "text": msg.content
                    ]
                    
                    if let memoryId = msg.memoryId {
                        dict["memory_id"] = memoryId
                    }
                    
                    if let items = msg.items {
                        let itemsDict = items.map { item -> [String: Any] in
                            var idict: [String: Any] = [:]
                            if let name = item.itemName { idict["item_name"] = name }
                            if let price = item.price { idict["price"] = price }
                            if let date = item.date { idict["date"] = date }
                            if let merchant = item.merchantName { idict["merchant_name"] = merchant }
                            return idict
                        }
                        dict["items"] = itemsDict
                    }
                    
                    return dict
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
    
    private func handleAnimationEnd(for id: UUID) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            // Only update if it was animating to prevent unnecessary writes
            if messages[index].shouldAnimate {
                messages[index].shouldAnimate = false
            }
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

// Global Helper (File Private)
fileprivate func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred()
}

// MARK: - Extracted Subviews
extension ChatView {
    private var headerView: some View {
        VStack(spacing: 0) {
            ZStack {
                // Layer 1: Left and Right Controls
                HStack(spacing: 0) {
                    // Left: Profile & Menu
                    Menu {
                        Button(role: .destructive, action: {
                            authManager.logout()
                        }) {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // Profile Image
                            if let avatarURL = authManager.user?.avatarURL {
                                AsyncImage(url: avatarURL) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 32, height: 32)
                                            .overlay(Text((authManager.user?.bestDisplayName.prefix(1) ?? "U").uppercased())
                                                .foregroundColor(.white))
                                    }
                                }
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .overlay(Text((authManager.user?.bestDisplayName.prefix(1) ?? "U").uppercased())
                                        .foregroundColor(.white))
                            }
                            
                            // Greeting & Name
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentGreeting)
                                    .font(.custom("FKGroteskTrial-Regular", size: 10)) // Reduced from 12
                                    .foregroundColor(.gray)
                                
                                Text(authManager.user?.fullName ?? authManager.user?.bestDisplayName ?? "User")
                                    .font(.custom("FKGroteskTrial-Medium", size: 14)) // Reduced from 16
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.leading, 16)
                    }
                    
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
                
                // Layer 2: Centered Logo
                OwlitLogo(size: 24)
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(headerBlack)
    }
    
    private var currentGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Centered Logo in Light Gray
            OwlitLogo(size: 80)
                .grayscale(1.0)
                .opacity(0.3)
            
            // Tagline
            Text("")
                .font(.custom("FKGroteskTrial-Regular", size: 14))
                .foregroundColor(.white.opacity(0.4)) // Slightly dimmer to match logo
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()    
        }
        .frame(maxWidth: .infinity)
    }


}

// MARK: - Isolated Input Bar View
// This view manages its own state for sheets, preventing re-renders of the main list
struct ChatInputBar: View {
    var onSubmit: (String) -> Void
    var onImageSelected: (UIImage) -> Void
    var onManualTap: () -> Void
    var isManualMode: Bool // NEW
    
    @State private var prompt: String = ""
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    
    @FocusState private var isFocused: Bool // Auto-Focus State
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Text Field Area
                TextField("Ask Anything Or   Scan Receipt", text: $prompt)
                    .font(.custom("FKGroteskTrial-Regular", size: 16))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .submitLabel(.send)
                    .focused($isFocused)
                    .task {
                        // Delay slightly to allow transition to finish
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                        isFocused = true
                    }
                
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
                        Image(systemName: isManualMode ? "keyboard.fill" : "keyboard")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(isManualMode ? Color(hex: "FF4500") : .gray) // Fire Orange if active
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
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(prompt.isEmpty ? Color.gray.opacity(0.3) : Color.white)
                            .clipShape(Circle())
                    }
                    .disabled(prompt.isEmpty)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.02)) // 99% Transparent
            // .background(.ultraThinMaterial) // Removed to achieve transparency
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LinearGradient(
                        colors: [
                            .white.opacity(0.6), // Specular Top-Left
                            .white.opacity(0.2), 
                            .white.opacity(0.05) // Faded Bottom-Right
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 10) // Deep Shadow for Float
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(Color.clear) // Input Bar itself has no background, it floats
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
    var onAnimationEnd: (() -> Void)? = nil
    var onMerchantTap: ((String) -> Void)? = nil

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
                                .frame(maxWidth: .infinity, alignment: .center) // Center Image
                        }
                        
                        Text(message.content)
                            .font(.custom("FKGroteskTrial-Regular", size: 17))
                            .foregroundColor(message.style == .success ? .white : (message.style == .error ? Color(hex: "FF3B30") : .white.opacity(0.9)))
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
                    .background(message.style == .success ? Color(hex: "56CCF2") : Color(white: 0.15))
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
                                    onAnimationEnd?()
                                }
                            }
                            .environment(\.openURL, OpenURLAction { url in
                                if url.scheme == "merchant" {
                                    let merchantName = url.absoluteString.replacingOccurrences(of: "merchant://", with: "")
                                    onMerchantTap?(merchantName)
                                    return .handled
                                }
                                return .systemAction
                            })
                        } else {
                            Text(TextFormatter.format(message.content))
                                .font(.custom("FKGroteskTrial-Regular", size: 17)) // Reverted to FK Grotesk
                                .foregroundColor(.white.opacity(0.95))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .environment(\.openURL, OpenURLAction { url in
                                    if url.scheme == "merchant" {
                                        let merchantName = url.absoluteString.replacingOccurrences(of: "merchant://", with: "")
                                        onMerchantTap?(merchantName)
                                        return .handled
                                    }
                                    return .systemAction
                                })
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
                                    Button(action: { 
                                        triggerHaptic(style: .medium)
                                        onSuggestionTap?(suggestion) 
                                    }) {
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
    
    // UI Style
    var style: ChatMessageStyle = .normal
    
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
         shouldAnimate: Bool = false,
         style: ChatMessageStyle = .normal) {
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
        self.style = style
    }
}

enum ChatMessageStyle: String, Codable {
    case normal
    case success
    case error
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
        Text(TextFormatter.format(displayedText))
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
                
                // Haptic Feedback
                if displayedText.count % 3 == 0 {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            } else {
                timer.invalidate()
                onComplete?()
            }
        }
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
