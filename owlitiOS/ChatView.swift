//
//  ChatView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI

struct ChatView: View {
    @Binding var pendingReceipt: ReceiptData? // Data from Landing Page
    @Binding var pendingQuestion: String? // Question from Landing Page
    @Binding var pendingSharedImage: UIImage? // From Share Extension

    var onNavigateToHome: (() -> Void)? = nil
    
    // Default Init workaround if needed (optional)
    // Default Init workaround if needed (optional)
    init(pendingReceipt: Binding<ReceiptData?> = .constant(nil), pendingQuestion: Binding<String?> = .constant(nil), pendingSharedImage: Binding<UIImage?> = .constant(nil), onNavigateToHome: (() -> Void)? = nil) {
        self._pendingReceipt = pendingReceipt
        self._pendingQuestion = pendingQuestion
        self._pendingSharedImage = pendingSharedImage
        self.onNavigateToHome = onNavigateToHome
    }

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
    
    // Attached Image State (for share extension - attached to input box)
    @State private var attachedImage: UIImage?
    
    // UI Logic
    @State private var scanningSteps: [String] = []
    @State private var scanProgress: Double = 0.0 // Added for consistent animation with WelcomeLandingView
    @State private var showSuccessPopup = false
    @State private var inputOverlayHeight: CGFloat = 110 // Default start height
    
    // Finance Popup
    @State private var selectedMerchantResolution: MerchantResolution?
    @State private var isResolvingMerchant = false
    @State private var resolvingMerchantName: String?
    
    // UI Size State
    @State private var profileNameWidth: CGFloat = 120 // Default min width
    
    // Scroll Trigger (for explicit scroll requests)
    @State private var scrollTrigger: Int = 0
    
    // Copy Toast State
    @State private var showCopyToast = false
    @State private var showHealthOverview = false
    @State private var showSideMenu = false // Custom Sidebar State
    
    // Perplexity Header State
    @State private var activeTab: String = "chat" // chat, shop, analytics

    @State private var showLocalAnalytics = false
    @State private var showCrypto = false // Crypto Placeholder State
    @State private var showHistory = false // History Page State
    @State private var isEditingScan = false // State to toggle between Preview (Crypto) and Edit (ScanView)
    
    // Environment
    @Environment(\.openURL) var openURL

    
    // Focus State for Input Field
    @FocusState private var isInputFocused: Bool
    
    // Dynamic Theme Colors
    var themeBackground: Color { isDarkMode ? .black : Color(hex: "FAFAF5") } // Creamy White
    
    @Namespace private var namespace
    var themeText: Color { isDarkMode ? .white : .black }
    var themeSecondaryBackground: Color { isDarkMode ? Color(white: 0.12) : .white }
    var themeHeaderBackground: Color { isDarkMode ? Color.black.opacity(0.95) : Color(hex: "FAFAF5").opacity(0.95) }
    private var gridLineColor: Color { isDarkMode ? Color.white.opacity(0.035) : Color.black.opacity(0.02) }

    
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
                
                // MARK: - Layer 4: Analytics Overlay
                if showLocalAnalytics {
                    Analytics(onMenuTap: {
                        withAnimation { showSideMenu = true }
                    }, onClose: {
                        withAnimation { showLocalAnalytics = false }
                    })
                    .transition(.move(edge: .bottom))
                    .zIndex(4.5)
                }

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
            .background(
                ZStack {
                    themeBackground
                    MeshGrid(spacing: 8)
                        .stroke(gridLineColor, lineWidth: 0.5)
                }
                .ignoresSafeArea()
            )

            .ignoresSafeArea(.container, edges: .bottom) // Ensure Edge-to-Edge
            .preferredColorScheme(isDarkMode ? .dark : .light)
            
            // Success Popup Overlay
            if showSuccessPopup {
                SuccessOverlayView()
                    .transition(.opacity)
                    .zIndex(100)
            }
            
            // Shared Scanning Animation Overlay (From WelcomeLandingView)
            if isProcessingImage {
                ProcessingPopupView(steps: scanningSteps, progress: scanProgress)
                    .zIndex(101) // Above everything
                    .transition(.opacity)
            }
        }

        .sheet(isPresented: $showCrypto) {
            CryptoView(receiptData: nil, receiptImage: nil)
                .presentationDetents([.large]) // Full screen sheet
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHistory) {
            ReceiptHistoryView()
                .environmentObject(authManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }

        // Sheet for Receipt Review is top level logic
        .sheet(item: $scannedData) { data in
            if isEditingScan {
                ScanReceiptView(
                    image: selectedImage ?? UIImage(), 
                    data: data, 
                    saveMode: .local,
                    onSaveSuccess: { savedData in
                        // On Edit Save:
                        // We can either go back to Preview OR just Save/Finish.
                        // User said: "edit button on receipt preview table... let edit the receipt".
                        // Usually this implies saving changes updates the preview?
                        // Let's assume on Edit Save, we update `scannedData` and go back to Preview.
                        
                        self.scannedData = savedData // Update local data
                        self.isEditingScan = false // Go back to Preview
                    },
                    onCancel: {
                         // User Cancelled Edit - Go back to Preview without changes
                         print("↩️ User cancelled edit, returning to CryptoView preview")
                         withAnimation {
                            self.isEditingScan = false
                         }
                    }
                )
            } else {
                CryptoView(
                    receiptData: data, 
                    receiptImage: selectedImage, 
                    onConfirm: { finalData in
                        // perform SAVE logic
                        Task {
                            guard let token = authManager.token else { return }
                            
                            var saveParams = ["receiptData": ""]
                            if let jsonData = try? JSONEncoder().encode(finalData),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                saveParams["receiptData"] = jsonString
                            }
                            
                            let imageData = selectedImage?.jpegData(compressionQuality: 0.6)
                            
                            do {
                                _ = try await APIClient.shared.uploadRequest(path: "/api/receipts", data: imageData, fileName: "receipt.jpg", fieldName: "receiptImage", mimeType: "image/jpeg", parameters: saveParams, token: token)
                                
                                await MainActor.run {
                                    if let editingId = editingMessageId,
                                       let index = messages.firstIndex(where: { $0.id == editingId }) {
                                        var updatedMsg = messages[index]
                                        updatedMsg.receiptData = finalData 
                                        withAnimation { messages[index] = updatedMsg }
                                        self.editingMessageId = nil
                                    } else {
                                        let summaryMsg = ChatMessage(content: "Receipt Saved", isUser: false, receiptData: finalData, image: selectedImage, style: .success)
                                        withAnimation { messages.append(summaryMsg) }
                                    }
                                    
                                    // Reset
                                    self.scannedData = nil
                                    self.selectedImage = nil
                                }
                            } catch {
                                print("Save error: \(error)")
                            }
                        }
                    },
                    onEdit: {
                        // Toggle Layout to Edit Mode
                        self.isEditingScan = true
                    }
                )

                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
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
            
            // Check for pending receipt from Landing Page
            if let receipt = pendingReceipt {
                print("🚀 ChatView.onAppear: Found Pending Receipt. Image: \(receipt.originalImage != nil)")
                handleLocalReceiptIngestion(receipt)
                self.pendingReceipt = nil // Clear it
                // Do NOT focus input ensuring collapsed state
                // Do NOT focus input ensuring collapsed state
                isInputFocused = false
            } else if let question = pendingQuestion {
                // Handle pending question from Landing Page
                submitQuery(question)
                self.pendingQuestion = nil
                isInputFocused = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
            }
            
            // Check for Shared Image (App Group)
            checkForSharedImage()
        }
        .onChange(of: pendingSharedImage) { newImage in
             checkForSharedImage()
        }
        .onChange(of: isProcessingImage) { isProcessing in
            // Clear attached image once processing actually starts
            if isProcessing && attachedImage != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.attachedImage = nil
                }
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
                    
                    // Spacer for input area - Dynamic Height + Safety Buffer
                    Color.clear.frame(height: inputOverlayHeight + 120).id("BOTTOM")
                }
                .padding(.bottom, 0)
            }
            .background(Color.clear)
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
                    attachedImage: $attachedImage,
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
                    print("📝 Edit Tap: Receipt has Image? \(data.originalImage != nil)")
                    
                    // Fallback to message image if receipt data lost it
                    let finalImage = data.originalImage ?? message.image
                    
                    if finalImage == nil {
                         print("❌ WARNING: Receipt image is NIL (even after fallback). Edit will fail.")
                    }
                    
                    // Trigger the sheet with existing data
                    // Ensure we pass the image back into the data if it was missing from struct
                    var fixedData = data
                    if fixedData.originalImage == nil { fixedData.originalImage = finalImage }
                    
                    self.scannedData = fixedData
                    self.selectedImage = finalImage
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
    

    
    // ... Subviews Definitions
    


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
    
    func checkForSharedImage() {
        if let image = pendingSharedImage {
            print("🚀 ChatView: Attaching and Auto-Processing Shared Image from Extension")
            // Attach image to input box for visual feedback
            attachedImage = image
            // Clear it so we don't re-trigger
            self.pendingSharedImage = nil
            // Automatically start processing the image (no need to hit send button)
            // Small delay to ensure UI updates first so user sees the image attached
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.handleImageSelection(image)
                // attachedImage will be cleared automatically when isProcessingImage becomes true
            }
        }
    }
    
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
                
                // Decode on background thread
                let chats = try await Task.detached(priority: .userInitiated) {
                    try JSONDecoder().decode([RecentChat].self, from: data)
                }.value
                
                await MainActor.run {
                    self.recentChats = Array(chats.prefix(5)) // Show top 5
                }
            } catch {
                print("⚠️ Failed to load chats: \(error)")
                // Fallback to quick replies if fetch fails? Or just empty.
            }
        }
    }
    // Dynamically resolve and open the summary for the user's most frequent shop
    private func openTopMerchantSummary() {
        Task {
            // OPTIMIZATION: Check Local Analytics Manager Cache First (Instant)
            // This avoids the 1-second delay from network calls
            if let topMerchant = AnalyticsManager.shared.getTopMerchantName() {
                print("⚡️ [ChatView] Instant Local Hit for Top Merchant: \(topMerchant)")
                await MainActor.run {
                     self.selectedMerchantResolution = MerchantResolution(
                        id: topMerchant.lowercased().filter { $0.isLetter || $0.isNumber }, 
                        displayName: topMerchant
                     )
                }
                return
            }
            
            // Fallback: Network Request (If cache empty)
            guard let token = authManager.token else { return }
            
            do {
                let merchants = try await APIClient.shared.fetchFilteredMerchants(token: token)
                
                if let topMerchant = merchants.first {
                    let resolution = try await APIClient.shared.resolveMerchant(name: topMerchant, token: token)
                    await MainActor.run {
                        self.selectedMerchantResolution = resolution
                    }
                } else {
                    await MainActor.run {
                        self.selectedMerchantResolution = MerchantResolution(id: "tesco", displayName: "Tesco")
                    }
                }
            } catch {
                print("⚠️ Failed to resolve top merchant: \(error)")
                await MainActor.run {
                    self.selectedMerchantResolution = MerchantResolution(id: "tesco", displayName: "Tesco")
                }
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
        scanProgress = 0.0
        
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
            // Simulator for Steps (Optimistic Progress)
            var isFinished = false
            let progressTask = Task {
                 // Phase 1: Milestones
                 for (index, step) in steps.enumerated() {
                     if isFinished { break }
                     
                     // Stop before final step to wait for API
                     if index == steps.count - 1 { break }
                     
                     await MainActor.run {
                         withAnimation {
                             scanningSteps.append(step)
                             self.scanProgress = Double(scanningSteps.count) / Double(steps.count)
                         }
                     }
                     
                     let delay = index < 3 ? 0.4 : 0.8
                     try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                 }
                 
                 // Phase 2: The "Creep"
                 while !isFinished && scanProgress < 0.99 {
                     try? await Task.sleep(nanoseconds: 1_000_000_000)
                     if isFinished { break }
                     await MainActor.run {
                         withAnimation(.linear(duration: 1.0)) {
                             scanProgress += 0.01
                         }
                     }
                 }
            }
            
            do {
                let params = ["scanMode": "receipt", "highAccuracy": "false"]
                let (data, _) = try await APIClient.shared.uploadRequest(path: "/api/scan", data: imageData, fileName: "upload.jpg", mimeType: "image/jpeg", parameters: params, token: token)
                var receipt = try JSONDecoder().decode(ReceiptData.self, from: data)
                
                // Attach image locally
                receipt.originalImage = resizedImage
                
                // MARK: - Success Handling
                isFinished = true
                progressTask.cancel() // Stop the creeper
                
                // 1. Force Progress to 100%
                await MainActor.run {
                    // Ensure all previous steps are present
                    if scanningSteps.count < steps.count - 1 {
                        scanningSteps = Array(steps.dropLast())
                    }
                    withAnimation {
                        if !scanningSteps.contains(steps.last!) {
                            scanningSteps.append(steps.last!)
                        }
                        self.scanProgress = 1.0
                    }
                }
                
                // 2. Short visual pause
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                await MainActor.run {
                    self.isProcessingImage = false
                    self.scanningSteps = [] // Clear steps
                    self.isInputFocused = false
                    
                    // Trigger Preview Sheet (CryptoView) instead of Auto-Save
                    self.scannedData = receipt
                    self.selectedImage = resizedImage
                }
            } catch {
                isFinished = true
                progressTask.cancel()
                await MainActor.run {
                    self.isProcessingImage = false
                    self.scanningSteps = []
                    self.isInputFocused = false
                    messages.append(ChatMessage(content: "❌ Error: \(error.localizedDescription)", isUser: false))
                }
            }
        }
    }
    
    // Helper to ingest receipt from Landing Page
    func handleLocalReceiptIngestion(_ receipt: ReceiptData) {
        // Robust Image Recovery
        var imageToUse = receipt.originalImage
        
        // 1. Check Singleton if struct failed
        if imageToUse == nil {
            print("⚠️ ChatView: Struct missing image. Checking Singleton...")
            if let transferImage = ImageTransfer.shared.pendingImage {
                print("✅ Rec recovered image from Singleton!")
                imageToUse = transferImage
                // Clear singleton after retrieval to free memory
                ImageTransfer.shared.pendingImage = nil 
            }
        }
        
        print("🚀 ChatView.ingest: Final Image Present? \(imageToUse != nil)")
        
        // 2. Trigger Crypto Preview instead of saving to Chat
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
             withAnimation {
                 var fixedReceipt = receipt
                 fixedReceipt.originalImage = imageToUse // Ensure struct has it
                 
                 // Trigger Sheet
                 self.selectedImage = imageToUse
                 self.scannedData = fixedReceipt
                 self.isEditingScan = false
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
        
        // If there's an attached image, handle it with the text
        if let image = attachedImage {
            // Create user message with both image and text
            let userMsg = ChatMessage(
                content: trimmed.isEmpty ? "" : trimmed,
                isUser: true,
                image: image
            )
            
            // Clear suggestions from all previous messages
            for index in messages.indices {
                messages[index].suggestedQuestions = nil
            }
            
            withAnimation {
                messages.append(userMsg)
                isLoading = true
            }
            
            // Clear attached image
            attachedImage = nil
            
            // Process image with optional text context
            processImageWithText(image: image, text: trimmed)
            return
        }
        
        // No image attached - standard text-only flow
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
    
    // New function to handle image + text submission
    private func processImageWithText(image: UIImage, text: String) {
        // If text is empty, treat it as a receipt scan (existing behavior)
        if text.isEmpty {
            handleImageSelection(image)
            return
        }
        
        // If text is provided, we'll process the image normally first
        // Then send the text as a follow-up question after the image is processed
        // Store the text to send after image processing
        let questionToAsk = text
        
        // Process image first (this will show the receipt preview)
        // We'll modify handleImageSelection to accept an optional callback
        // For now, let's use a simpler approach: process image, then ask question
        hideKeyboard()
        selectedImage = image
        isProcessingImage = true
        isManualEntry = false
        scanningSteps = []
        
        let steps = [
            "Analyzing Image...",
            "Processing Content...",
            "Preparing Response..."
        ]
        
        let resizedImage = image.resized(toMaxDimension: 1200)
        
        guard let token = authManager.token,
              let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            isProcessingImage = false
            return
        }
        
        Task {
            // Simulate steps for UX
            for step in steps {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s per step
                await MainActor.run {
                    scanningSteps.append(step)
                }
            }
            
            do {
                // Scan the image to get receipt data
                let scanParams: [String: String] = [:]
                let (scanData, _) = try await APIClient.shared.uploadRequest(
                    path: "/api/scan",
                    data: imageData,
                    fileName: "receipt.jpg",
                    fieldName: "file",
                    mimeType: "image/jpeg",
                    parameters: scanParams,
                    token: token
                )
                
                let receiptData = try JSONDecoder().decode(ReceiptData.self, from: scanData)
                
                await MainActor.run {
                    self.scannedData = receiptData
                    self.selectedImage = resizedImage
                    self.isProcessingImage = false
                    self.scanningSteps = []
                    
                    // Now automatically ask the question about the receipt
                    // Add a small delay to ensure UI is updated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Create a question that includes receipt context
                        let contextualQuestion = "Based on this receipt from \(receiptData.merchantName ?? "the merchant"), \(questionToAsk)"
                        self.performAIRequest(question: contextualQuestion, isRetry: false)
                    }
                }
            } catch {
                print("❌ Image processing error: \(error)")
                await MainActor.run {
                    isProcessingImage = false
                    scanningSteps = []
                    isLoading = false
                    messages.append(ChatMessage(content: "Failed to process image. Please try again.", isUser: false))
                }
            }
        }
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
                
                // Inject System Persona
                var finalHistory = history
                let userName = authManager.user?.bestDisplayName ?? "User"
                let systemInstruction = "You are Owlit, a witty, chatty, and playful financial assistant. Address the user as \(userName) occasionally. Use emojis ⚡️ and keep the vibe fun but helpful."
                
                finalHistory.insert(["role": "system", "text": systemInstruction], at: 0)
                
                var body: [String: Any] = ["question": question, "history": finalHistory]
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
        ZStack(alignment: .top) {
            if isInputFocused {
                perplexityHeader
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                defaultHeader
                    .transition(.opacity)
                    .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isInputFocused)
    }
    
    private var perplexityHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Back Button (Dismiss Keyboard)
                Button(action: {
                    hideKeyboard()
                }) {
                    Circle()
                        .fill(isDarkMode ? Color(white: 0.15) : Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(themeText)
                        )
                }
                .padding(.leading, 8) // Reduced padding from 16
                
                Spacer() // Equal Spacing
                
                // Central Pill
                HStack(spacing: 0) {
                    // Segment 1: Owlit Logo (Chat)
                    Button(action: {
                        withAnimation { activeTab = "chat" }
                        hideKeyboard()
                    }) {
                        ZStack {
                            if activeTab == "chat" {
                                Capsule()
                                    .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1)) // Darker Gray
                                    .padding(4)
                                    .matchedGeometryEffect(id: "activeTab", in: namespace)
                            }
                            OwlitLogo(size: 18, isDarkMode: isDarkMode)
                        }
                        .frame(width: 80, height: 36)
                    }
                    
                    Divider().frame(height: 14).background(Color.gray.opacity(0.3))
                    
                    // Segment 2: Shop Icon (Financial Summary)
                    Button(action: {
                        withAnimation { activeTab = "shop" } // Fix: Update state
                        triggerHaptic(style: .light)
                        openTopMerchantSummary()
                    }) {
                        ZStack {
                            if activeTab == "shop" {
                                Capsule()
                                    .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1)) // Darker Gray
                                    .padding(4)
                                    .matchedGeometryEffect(id: "activeTab", in: namespace)
                            }
                            Image(systemName: "storefront.fill")
                                .font(.system(size: 14))
                                .foregroundColor(activeTab == "shop" ? themeText : themeText.opacity(0.7))
                        }
                        .frame(width: 80, height: 36)
                    }
                    
                    Divider().frame(height: 14).background(Color.gray.opacity(0.3))
                    
                    // Segment 3: Analytics Icon (External Insights)
                    Button(action: {
                        withAnimation { activeTab = "analytics" }
                        withAnimation { showLocalAnalytics = true }
                    }) {
                        ZStack {
                            if activeTab == "analytics" {
                                Capsule()
                                    .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1)) // Darker Gray
                                    .padding(4)
                                    .matchedGeometryEffect(id: "activeTab", in: namespace)
                            }
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 14))
                                .foregroundColor(activeTab == "analytics" ? themeText : themeText.opacity(0.7))
                        }
                        .frame(width: 80, height: 36)
                    }
                }
                .background(isDarkMode ? Color(white: 0.15) : Color.black.opacity(0.08)) // Darker Container Gray
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.05), lineWidth: 1))
                
                Spacer() // Equal Spacing
                
                // Share Button
                Button(action: {
                    triggerHaptic(style: .light)
                }) {
                    Circle()
                        .fill(isDarkMode ? Color(white: 0.15) : Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(themeText)
                        )
                }
                .padding(.trailing, 8)
            }
            .padding(.vertical, 8)
        }
        .background(themeHeaderBackground)
    }


    private var defaultHeader: some View {
        VStack(spacing: 0) {
            ZStack {
                // Layer 1: Left and Right Controls
                HStack(spacing: 0) {
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
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
                            })
                            .onPreferenceChange(WidthPreferenceKey.self) { newWidth in
                                self.profileNameWidth = newWidth
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
                OwlitLogo(size: 24, isDarkMode: isDarkMode)
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
                // Home (Landing Page)
                Button(action: {
                    triggerHaptic(style: .medium)
                    showSideMenu = false
                    onNavigateToHome?()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "house")
                            .font(.system(size: 10))
                            .foregroundColor(themeText)
                            .frame(width: 20, height: 20)
                            .background(themeSecondaryBackground)
                            .clipShape(Circle())
                        
                        Text("Home")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(themeText)
                    }
                }
                
                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                // My Shops (Same as Shop Icon)
                Button(action: {
                    triggerHaptic(style: .medium)
                    showSideMenu = false
                    openTopMerchantSummary()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 10))
                            .foregroundColor(themeText)
                            .frame(width: 20, height: 20)
                            .background(themeSecondaryBackground)
                            .clipShape(Circle())
                        
                        Text("My Shops")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(themeText)
                    }
                }
                
                // Insights (Same as Analytics Icon)
                Button(action: {
                    triggerHaptic(style: .medium)
                    showSideMenu = false
                    withAnimation { showLocalAnalytics = true }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 10))
                            .foregroundColor(themeText)
                            .frame(width: 20, height: 20)
                            .background(themeSecondaryBackground)
                            .clipShape(Circle())
                        
                        Text("Insights")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(themeText)
                    }
                }

                // History
                Button(action: {
                    triggerHaptic(style: .medium)
                    showSideMenu = false
                    showHistory = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                            .foregroundColor(themeText)
                            .frame(width: 20, height: 20)
                            .background(themeSecondaryBackground)
                            .clipShape(Circle())
                        
                        Text("History")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(themeText)
                    }
                }
                
                // Crypto (New)
                Button(action: {
                    triggerHaptic(style: .medium)
                    showSideMenu = false
                    showCrypto = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bitcoinsign.circle")
                            .font(.system(size: 10))
                            .foregroundColor(themeText)
                            .frame(width: 20, height: 20)
                            .background(themeSecondaryBackground)
                            .clipShape(Circle())
                        
                        Text("Crypto")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(themeText)
                    }
                }

                // Analytics
                Button(action: {
                    triggerHaptic(style: .medium)
                    showSideMenu = false
                    showLocalAnalytics = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                            .foregroundColor(themeText)
                            .frame(width: 20, height: 20)
                            .background(themeSecondaryBackground)
                            .clipShape(Circle())
                        
                        Text("Analytics")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(themeText)
                    }
                }
                
                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                // Theme Toggle
                Button(action: {
                    triggerHaptic(style: .medium)
                    isDarkMode.toggle()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isDarkMode ? "sun.max" : "moon")
                            .font(.system(size: 10))
                            .foregroundColor(themeText)
                            .frame(width: 20, height: 20)
                            .background(themeSecondaryBackground)
                            .clipShape(Circle())
                        
                        Text("Theme")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(themeText)
                    }
                }
                
                // Divider (Small)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                // Logout
                Button(action: {
                    triggerHaptic(style: .medium)
                    showSideMenu = false
                    authManager.logout()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .frame(width: 20, height: 20)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text("Log out")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(8) // Inner padding
            .fixedSize(horizontal: true, vertical: false)
            .ultraGlass(cornerRadius: 8)
            .padding(.top, 50)
            .padding(.leading, 20) // Restored original position
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
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
    @Binding var attachedImage: UIImage? // Attached image from share extension

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
                // Attached Image Preview (if any)
                if let image = attachedImage {
                    HStack(spacing: 8) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Image attached")
                                .font(.custom("FKGroteskTrial-Regular", size: 12))
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                            Text("Tap to remove")
                                .font(.custom("FKGroteskTrial-Regular", size: 10))
                                .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                attachedImage = nil
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                
                // 1. Text Field Area
                TextField("Ask Anything...", text: $prompt)
                    .font(.custom("FKGroteskTrial-Regular", size: 16))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .foregroundColor(isDarkMode ? .white : .black)
                    .accentColor(isDarkMode ? .white : .black)
                    .submitLabel(.send)
                    .focused(isFocused)
                    .onSubmit {
                        // Allow sending even if prompt is empty when image is attached
                        if !prompt.isEmpty || attachedImage != nil {
                            onSubmit(prompt)
                            prompt = ""
                        }
                    }
                
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
                            .background((prompt.isEmpty && attachedImage == nil) ? Color.gray.opacity(0.3) : (isDarkMode ? Color.white : Color.black))
                            .clipShape(Circle())
                    }
                    .disabled(prompt.isEmpty && attachedImage == nil)
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

struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
