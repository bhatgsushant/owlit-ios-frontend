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
    @AppStorage("isDarkMode") var isDarkMode = true
    
    // Receipt Scanning State (Maintained at top level to handle the result)
    @State private var scannedData: ReceiptData?
    @State private var isProcessingImage = false
    @State private var selectedImage: UIImage?
    @State private var isManualEntry = false
    @State private var editingMessageId: UUID? // Generic ID for message being edited
    
    // UI Logic
    @State private var scanningSteps: [String] = []
    @State private var showSuccessPopup = false
    @State private var inputOverlayHeight: CGFloat = 110 // Default start height
    
    // Finance Popup
    @State private var selectedMerchantResolution: MerchantResolution?
    @State private var isResolvingMerchant = false
    @State private var resolvingMerchantName: String?
    
    // Scroll Trigger (for explicit scroll requests)
    @State private var scrollTrigger: Int = 0
    
    // Copy Toast State
    @State private var showCopyToast = false
    @State private var showHealthOverview = false
    @State private var showSideMenu = false // Custom Sidebar State

    
    // Focus State for Input Field
    @FocusState private var isInputFocused: Bool
    
    // Dynamic Theme Colors
    var themeBackground: Color { isDarkMode ? .black : Color(hex: "FAFAF5") } // Creamy White
    var themeText: Color { isDarkMode ? .white : .black }
    var themeSecondaryBackground: Color { isDarkMode ? Color(white: 0.12) : .white }
    var themeHeaderBackground: Color { isDarkMode ? Color.black.opacity(0.95) : Color(hex: "FAFAF5").opacity(0.95) }
    
    // Legacy fixed colors (keeping for reference if needed, but mostly replacing)
    let pitchBlack = Color.black 

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
                scrollableContent
                
                // MARK: - Layer 1: Header Overlay
                headerView
                    .zIndex(2)
                
                // MARK: - Layer 2: Input Bar Overlay
                inputOverlay
                    .zIndex(3)
                
                // MARK: - Layer 3: Toast Overlay
                toastOverlay
                    .zIndex(4)
                
                // MARK: - Layer 5: Side Menu Overlay
                if showSideMenu {
                    sideMenuView
                        .zIndex(5)
                        .transition(.opacity)
                }
                    
                // MARK: - Layer 4: Loading Overlay (Merchant Resolution)
                if isResolvingMerchant {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                            Text("Resolving \(resolvingMerchantName ?? "Merchant")...")
                                .font(.custom("FKGroteskTrial-Regular", size: 14))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(Color(white: 0.15))
                        .cornerRadius(12)
                    }
                    .zIndex(10)
                    .transition(.opacity)
                }
            }
            .blur(radius: showSuccessPopup ? 10 : 0) // Blur main content when popup is active
            .background(themeBackground)

            .ignoresSafeArea(.container, edges: .bottom) // Ensure Edge-to-Edge
            .preferredColorScheme(isDarkMode ? .dark : .light)
            
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
        // Finance Sheet (Isolated to prevent conflict)
        .background(
            EmptyView()
                .sheet(item: Binding<MerchantResolution?>(
                    get: { selectedMerchantResolution },
                    set: { selectedMerchantResolution = $0 }
                )) { res in
                    FinancialSummaryView(merchantId: res.id, merchantName: res.displayName)
                        .environmentObject(authManager)
                        .presentationDetents([.fraction(0.6), .medium, .large])
                        .presentationDragIndicator(.visible)
                }
        )
        .onAppear { 
            loadRecentChats()
            // Auto-focus input on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
    
    // MARK: - Extracted Subviews for Main Body
    private var scrollableContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
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
                    messageList(proxy: proxy)
                    
                    // Scanning Progress moved to floating overlay
                    
                    if isLoading {
                        typingIndicator
                            .padding(.leading, 20)
                            .padding(.top, 4)
                    }
                    
                    // Spacer for input area - Reduced to tighten layout
                    // Spacer for input area - Reduced to tighten layout
                    // Scanning Progress (In-flow)
                    scanningProgressSection
                    
                    // Spacer for input area - Dynamic Height + Safety Buffer
                    Color.clear.frame(height: inputOverlayHeight + 120).id("BOTTOM")
                }
                .padding(.bottom, 0)
            }
            .background(themeBackground)
            .ignoresSafeArea() // True Full Screen
            .onChange(of: messages.count) { _ in
                // Delay slightly to allow layout to settle
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                    await MainActor.run {
                        withAnimation {
                            if let last = messages.last, last.receiptData != nil {
                                // For receipts, scroll to show the top of the message (better visibility)
                                // We target the message ID directly
                                proxy.scrollTo(last.id, anchor: .center)
                            } else {
                                proxy.scrollTo("BOTTOM", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .onChange(of: isLoading) { _ in
                // Scroll when loading state changes (typing indicator appears/disappears)
                Task {
                    try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s
                    await MainActor.run {
                        withAnimation {
                            proxy.scrollTo("BOTTOM", anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: scanningSteps.count) { _ in
                 withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
            }
            .onChange(of: scrollTrigger) { _ in
                // Explicit scroll trigger - longer delay for suggested question taps
                Task {
                    try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s - wait for layout
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("BOTTOM", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .zIndex(0)
        .onTapGesture {
            // Dimiss Keyboard on Tap
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    private var inputOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                // Specific placement for Scanning Progress: Moved to ScrollView
                
                ChatInputBar(
                    onSubmit: { query in submitQuery(query) },
                    onImageSelected: { image in handleImageSelection(image) },
                    onManualTap: { toggleManualMode() },
                    onInsightsTap: { showHealthOverview = true },

                    isManualMode: isManualEntry,
                    isDarkMode: isDarkMode,
                    isFocused: $isInputFocused
                )
                .padding(.bottom, 10) // Lift slightly from edge
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(HeightPreferenceKey.self) { newHeight in
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.inputOverlayHeight = newHeight
                    }
                }
            }
            // Prevent tap-through on the input area
            .contentShape(Rectangle()) 
        }
    }
    
    private var toastOverlay: some View {
        VStack {
            if showCopyToast {
                VStack {
                    Spacer()
                    Text("Copied to Clipboard")
                        .font(.custom("FKGroteskTrial-Medium", size: 14))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(Color.black.opacity(0.8))
                        .clipShape(Capsule())
                        .shadow(radius: 10)
                        .padding(.bottom, 120) // Above input bar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    // Helper Views to reduce complexity
    private func messageList(proxy: ScrollViewProxy) -> some View {
        ForEach(messages) { message in
            MessageBubble(
                message: message,
                onFeedback: { isPositive in
                    sendFeedback(message: message, isPositive: isPositive)
                },
                onSuggestionTap: { suggestion in
                    submitQuery(suggestion)
                    // Trigger explicit scroll after suggestion tap
                    scrollTrigger += 1
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
                onMerchantTap: { merchantName in
                    // Start Resolution
                    Task {
                         await MainActor.run { 
                             self.isResolvingMerchant = true 
                             self.resolvingMerchantName = merchantName
                         }
                         
                         do {
                             if let token = authManager.token {
                                 let resolution = try await APIClient.shared.resolveMerchant(name: merchantName, token: token)
                                 await MainActor.run {
                                     self.selectedMerchantResolution = resolution
                                     self.isResolvingMerchant = false
                                     self.resolvingMerchantName = nil
                                 }
                             }
                         } catch {
                             print("❌ Failed to resolve merchant: \(error)")
                             await MainActor.run {
                                 self.isResolvingMerchant = false
                                 self.resolvingMerchantName = nil
                                 // Show specific error for debugging
                                 self.messages.append(ChatMessage(content: "Error: \(error.localizedDescription)", isUser: false))
                             }
                         }
                    }
                },
                onUpdate: {
                    // Scroll to bottom during typing
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                },
                onCopy: { content in
                    handleCopy(content)
                },
                isDarkMode: isDarkMode,
                onRegenerate: {
                    regenerateAnswer(for: message)
                }
            )
            .id(message.id)
        }
    }
    
    private var scanningProgressSection: some View {
        Group {
            if !scanningSteps.isEmpty {
                ScanningProgressView(steps: scanningSteps, isDarkMode: isDarkMode)
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id("SCANNING_PROGRESS")
            }
        }
    }
    
    // ... Subviews Definitions
    
    struct ScanningProgressView: View {
        let steps: [String]
        var isDarkMode: Bool = true // Theme Prop
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Progress Bar
                // Progress Bar Row with Animated Logo
                HStack(spacing: 12) {
                    OwlitLogo(size: 30, isScanning: true)
                    
                    // Modern Sleek Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Track
                            Capsule()
                                .fill((isDarkMode ? Color.white : Color.gray).opacity(isDarkMode ? 0.1 : 0.2))
                                .frame(height: 10)
                            
                            // Indicator
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(hex: "DFFF00"), Color.green]), // Yellowish-Green to Green
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: min(geometry.size.width, geometry.size.width * (Double(steps.count) / 8.0)), height: 10)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: steps.count)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 8) {
                    if let activeStep = steps.last {
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(isDarkMode ? .white : .black)
                            
                            Text(activeStep)
                                .font(.custom("FKGroteskTrial-Regular", size: 14))
                                .foregroundColor(isDarkMode ? .white : .black)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(isDarkMode ? Color(white: 0.12) : .white)
                        .clipShape(Capsule())
                        .id(activeStep) // Triggers transition on change
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
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
            "Checking for Anomalies",
            "Structuring for Preview",
            "Finalising and Previewing",
            "Processing Complete"
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
                    self.isInputFocused = false // Ensure keyboard stays collapsed
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
                            self.isInputFocused = false // Ensure keyboard is closed
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isFinished = true
                    self.isProcessingImage = false
                    self.scanningSteps = []
                    self.isInputFocused = false
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
        
        // Clear suggestions from all previous messages
        for index in messages.indices {
            messages[index].suggestedQuestions = nil
        }
        
        withAnimation {
            messages.append(userMsg)
            isLoading = true
        }
        
        // CHECK MANUAL MODE
        if isManualEntry {
             processManualTransaction(trimmed)
             return
        }
        
        // Perform standard request
        performAIRequest(question: trimmed, isRetry: false)
    }
    
    private func regenerateAnswer(for message: ChatMessage) {
        // 1. Find the index of this AI message
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        // 2. Find the *preceding* User message to get the question
        // We look backwards from index
        var questionText: String?
        for i in stride(from: index - 1, through: 0, by: -1) {
            if messages[i].isUser {
                questionText = messages[i].content
                break
            }
        }
        
        guard let originalQuestion = questionText else {
            print("❌ Could not find original question for regeneration.")
            return
        }
        
        print("🔄 Regenerating answer for: '\(originalQuestion)'")
        
        // 3. Remove the bad AI result from UI
        withAnimation {
            messages.remove(at: index)
            isLoading = true
        }
        
        // 4. Submit with isRetry: true
        // Note: The history sent to backend includes messages *up to* the current point.
        // Since we removed the AI message, `messages` now ends with the User message (usually).
        performAIRequest(question: originalQuestion, isRetry: true)
    }

    private func performAIRequest(question: String, isRetry: Bool) {
        Task {
            let requestId = UUID().uuidString.prefix(8)
            let start = Date()
            print("🚀 [Req: \(requestId)] Starting AI Request (Retry: \(isRetry)). Text Length: \(question.count)")
            
            do {
                // Limit history to last 10 messages to prevent payload bloat/timeout
                // Important: If isRetry is true, we have already removed the "bad" AI response from `messages`.
                // So `messages` should look correct (ending in the user prompt).
                let historyToUse = messages.suffix(10) // Use suffix, but check if we need to drop *current* pending user msg?
                                                       // Actually, submitQuery appends User Msg, then calls this.
                                                       // generateAnswer removes AI msg, so User Msg is last.
                                                       // So taking suffix(10) is correct.
                                                       // But wait, the backend typically expects history *excluding* the current question if we send "question" param?
                                                       // Or does it expect "question" to be the *newest* thing and history is context?
                                                       // Standard pattern: History contains previous turns. "question" is the current turn.
                                                       // If `messages` includes the current User Question (which it does), we should probably EXCLUDE it from history
                                                       // to avoid duplication if the backend appends "question" to context.
                                                       // Let's check previous code: `messages.dropLast().suffix(10)`.
                                                       // Ah, previous code: `historyToUse = messages.dropLast().suffix(10)`.
                                                       // It DROPPED the last message (User's new prompt) from history, and sent it as "question".
                                                       // Correct.
                
                let historyMessages = messages.dropLast() // Exclude the very last item (which is the current User prompt)
                
                // Safety: If for some reason messages is empty (shouldn't be), handle it.
                let historySlice = historyMessages.suffix(10)
                
                print("📜 [Req: \(requestId)] History Count: \(historySlice.count)")
                
                let history = historySlice.compactMap { msg -> [String: Any]? in
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
                
                var body: [String: Any] = ["question": question, "history": history]
                if isRetry {
                    body["isRetry"] = true
                }
                
                let bodyData = try JSONSerialization.data(withJSONObject: body)
                print("📦 [Req: \(requestId)] Payload Size: \(ByteCountFormatter.string(fromByteCount: Int64(bodyData.count), countStyle: .file))")
                
                let (data, response) = try await APIClient.shared.rawRequest(path: "/api/ask-ai", method: "POST", body: bodyData, token: authManager.token)
                
                let duration = Date().timeIntervalSince(start)
                print("✅ [Req: \(requestId)] Success! Duration: \(String(format: "%.2f", duration))s. Response Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
                
                // Inspect Response Code if available
                if let httpResponse = response as? HTTPURLResponse {
                     print("📡 [Req: \(requestId)] Status Code: \(httpResponse.statusCode)")
                }
                
                let aiResponse = try JSONDecoder().decode(AskAIResponse.self, from: data)
                
                await MainActor.run {
                    withAnimation {
                        isLoading = false
                        messages.append(ChatMessage(content: aiResponse.answer, isUser: false, items: aiResponse.itemsUsed, memoryId: aiResponse.memoryId, suggestedQuestions: aiResponse.suggestedQuestions, shouldAnimate: true))
                    }
                }
            } catch {
                let duration = Date().timeIntervalSince(start)
                print("❌ [Req: \(requestId)] Failed after \(String(format: "%.2f", duration))s. Error: \(error)")
                
                await MainActor.run {
                    withAnimation {
                        isLoading = false
                        messages.append(ChatMessage(content: "Sorry, something went wrong. (Debug: \(error.localizedDescription))", isUser: false))
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
                
                // If this is the last message, trigger a scroll to reveal suggestions
                // We add a slight delay via the existing scrollTrigger mechanism
                if index == messages.count - 1 {
                    scrollTrigger += 1
                }
            }
        }
    }
    
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }
    
    private func hideKeyboard() {
        isInputFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func handleCopy(_ content: String) {
        UIPasteboard.general.string = content
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopyToast = false }
        }
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
                    // Left: Profile & Menu (Now Custom Sidebar)
                    Button(action: {
                        withAnimation(.spring()) {
                            showSideMenu.toggle()
                        }
                    }) {
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
                                            .overlay(Circle().stroke(themeText.opacity(0.1), lineWidth: 1))
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
                                    .font(.custom("FKGroteskTrial-Regular", size: 10))
                                    .foregroundColor(.gray)
                                
                                Text(authManager.user?.fullName ?? authManager.user?.bestDisplayName ?? "User")
                                    .font(.custom("FKGroteskTrial-Medium", size: 14))
                                    .foregroundColor(themeText)
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
                            .foregroundColor(themeText)
                    }
                    .padding(.trailing, 16)
                }
                
                // Layer 2: Centered Logo
                OwlitLogo(size: 24)
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(themeHeaderBackground)
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
            
            
            // Tagline
            Text("")
                .font(.custom("FKGroteskTrial-Regular", size: 14))
                .foregroundColor(themeText.opacity(0.4)) // Slightly dimmer to match logo
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()    
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showHealthOverview) {
            HealthOverviewView()
        }
    }


    
    // MARK: - Side Menu
    private var sideMenuView: some View {
        ZStack(alignment: .topLeading) {
            // Background Dim (Tap to Close)
            Color.black.opacity(0.01) // Nearly invisible tap area, or standard dim
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showSideMenu = false }
                }
            
            // Sidebar Content
            VStack(alignment: .leading, spacing: 12) {
                // Theme Toggle
                Button(action: {
                    triggerHaptic(style: .medium)
                    isDarkMode.toggle()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: isDarkMode ? "sun.max" : "moon")
                            .font(.system(size: 12))
                            .foregroundColor(themeText)
                            .frame(width: 24, height: 24)
                            .background(themeSecondaryBackground)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        
                        Text("Theme")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(themeText)
                    }
                }
                
                // Divider (Small)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                    .padding(.trailing, 24) // Slight inset from right if needed, or just full width
                
                // Logout
                Button(action: {
                    triggerHaptic(style: .medium)
                    showSideMenu = false
                    authManager.logout()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        
                        Text("Log out")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(.red)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false) // Allow width to fit content
            .background(Color.clear) // Transparent Background
            .padding(.top, 60) // Offset to start below the Profile Photo (Header Height)
            .padding(.leading, 20) // Align Icon center with Profile
            .transition(.move(edge: .leading))
        }
    }
}

// MARK: - Isolated Input Bar View
// This view manages its own state for sheets, preventing re-renders of the main list
struct ChatInputBar: View {
    var onSubmit: (String) -> Void
    var onImageSelected: (UIImage) -> Void
    var onManualTap: () -> Void
    var onInsightsTap: () -> Void

    var isManualMode: Bool // NEW
    var isDarkMode: Bool // For Theme
    
    // Binding to Parent Focus State
    var isFocused: FocusState<Bool>.Binding
    
    @State private var prompt: String = ""
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Text Field Area
                TextField("Ask Anything...", text: $prompt)
                    .font(.custom("FKGroteskTrial-Regular", size: 16))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .foregroundColor(isDarkMode ? .white : .black)
                    .accentColor(isDarkMode ? .white : .black)
                    .submitLabel(.send)
                    .focused(isFocused)
                
                // 2. Action Row (Below Text)
                HStack(spacing: 2) {
                    // Plus Icon (Attachment Mock)
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(isDarkMode ? .gray : .black)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    
                    // Camera Icon
                    Button(action: { showCamera = true }) {
                        Image(systemName: "camera")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(isDarkMode ? .gray : .black)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    
                    // Photo/Gallery Icon
                    Button(action: { showPhotoLibrary = true }) {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(isDarkMode ? .gray : .black)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    
                    // Manual Entry
                    Button(action: { onManualTap() }) {
                        Image(systemName: isManualMode ? "keyboard.fill" : "keyboard")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(isManualMode ? .blue : (isDarkMode ? .gray : .black))
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
                            .background(prompt.isEmpty ? Color.gray.opacity(0.3) : (isDarkMode ? Color.white : Color.black))
                            .clipShape(Circle())
                    }
                    .disabled(prompt.isEmpty)
                }
            }
            .padding(12)
            .background(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05)) // Dynamic Tint
            .background(.ultraThinMaterial) // Frosty Glass Effect
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LinearGradient(
                        colors: [
                            (isDarkMode ? Color.white : Color.black).opacity(0.6), // Specular Top-Left
                            (isDarkMode ? Color.white : Color.black).opacity(0.2), 
                            (isDarkMode ? Color.white : Color.black).opacity(0.05) // Faded Bottom-Right
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
    var onUpdate: (() -> Void)? = nil
    var onCopy: ((String) -> Void)? = nil
    var isDarkMode: Bool = true

    // Callback for regenerate
    var onRegenerate: (() -> Void)? = nil

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
                        
                        if !message.content.isEmpty {
                            Text(message.content)
                                .font(.custom("FKGroteskTrial-Regular", size: 15))
                                .foregroundColor(message.style == .success ? .white : (message.style == .error ? Color(hex: "FF3B30") : (isDarkMode ? .white.opacity(0.9) : .black)))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Receipt Table (Restored for User Bubble)
                        if let receiptData = message.receiptData {
                            ReceiptTableView(
                                data: receiptData,
                                onEdit: { onEditReceipt?(receiptData) },
                                isDarkMode: isDarkMode
                            )
                            .frame(width: 280) // Keep width constrained for bubble
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(message.style == .success ? Color(hex: "56CCF2") : (isDarkMode ? Color(white: 0.12) : .white))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .trailing)
                    .onLongPressGesture(minimumDuration: 0.3) {
                        onCopy?(message.content)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12) // Spacing after user message
                
            } else {
                // AI MESSAGE - Full Width Document Style
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 1. Main Content Text (Full width)
                    if message.receiptData == nil {
                        if message.shouldAnimate {
                            TypewriterText(fullText: message.content, speed: 0.015, onComplete: {
                                withAnimation {
                                    isTypingFinished = true
                                    onAnimationEnd?()
                                }
                            }, onUpdate: {
                                onUpdate?()
                            }, isDarkMode: isDarkMode)
                            .environment(\.openURL, OpenURLAction { url in
                                if url.scheme == "merchant" {
                                    let rawName = url.absoluteString.replacingOccurrences(of: "merchant://", with: "")
                                    let merchantName = rawName.removingPercentEncoding ?? rawName
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onMerchantTap?(merchantName)
                                    return .handled
                                }
                                return .systemAction
                            })
                        } else {
                            Text(TextFormatter.format(message.content, isDarkMode: isDarkMode))
                                .font(.custom("FKGroteskTrial-Regular", size: 15)) // Reverted to FK Grotesk
                                .foregroundColor(isDarkMode ? .white.opacity(0.95) : .black.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .environment(\.openURL, OpenURLAction { url in
                                    if url.scheme == "merchant" {
                                        let rawName = url.absoluteString.replacingOccurrences(of: "merchant://", with: "")
                                        let merchantName = rawName.removingPercentEncoding ?? rawName
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                        Button(action: {
                             onCopy?(message.content) // Re-use copy handler
                        }) {
                            Image(systemName: "square.on.square")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        
                        // Regenerate Button
                        Button(action: {
                            triggerHaptic(style: .medium)
                            onRegenerate?()
                        }) {
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
                                            .foregroundStyle(isDarkMode ? Color.white.opacity(0.9) : .black)
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                            .background(isDarkMode ? Color(white: 0.12) : .white) // Match User Bubble or similar
                                            .clipShape(Capsule()) // Pill Shape
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing) // Force right alignment
                            .padding(.top, 8)
                            .transition(.opacity)
                            .id("SUGGESTIONS_\(message.id)")
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
    var onUpdate: (() -> Void)? = nil
    var isDarkMode: Bool = true // Theme Prop
    
    @State private var displayedText: String = ""
    @State private var timer: Timer?
    
    // We need to access the styling function.
    // ... (comments kept)
    
        // TypewriterText body
    var body: some View {
        Text(TextFormatter.format(displayedText, isDarkMode: isDarkMode))
            .font(.custom("FKGroteskTrial-Regular", size: 15))
            .foregroundColor(isDarkMode ? .white.opacity(0.95) : .black.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                startTyping()
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
            .onChange(of: fullText) { newValue in
                displayedText = ""
                startTyping()
            }
    }
    
    private func startTyping() {
        // Invalidate existing timer if any
        timer?.invalidate()
        
        guard displayedText.count < fullText.count else { return }
        displayedText = ""
        
        // Timer-based typing
        timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { timer in
            // Handle timer logic
            // Note: We use 'timer' from closure to avoid self-capture cycles if we used self.timer
            // But we need to capture self for displayedText/onUpdate
            
            if displayedText.count < fullText.count {
                let index = fullText.index(fullText.startIndex, offsetBy: displayedText.count)
                displayedText.append(fullText[index])
                
                // Trigger update callback ALWAYS
                DispatchQueue.main.async { 
                    onUpdate?() 
                }
                
                // Haptic Feedback (every 3 chars)
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

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
