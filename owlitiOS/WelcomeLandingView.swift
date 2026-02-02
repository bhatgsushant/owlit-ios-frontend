import SwiftUI

struct WelcomeLandingView: View {
    var onContinue: () -> Void
    var onScanSuccess: ((ReceiptData) -> Void)? = nil
    var onAskAI: ((String) -> Void)? = nil // New Callback
    var shouldAnimate: Bool = true // Default to true
    
    @EnvironmentObject var auth: AuthManager
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var isProcessing = false
    @State private var scanningSteps: [String] = []
    @State private var scanProgress: Double = 0.0 // 0.0 to 1.0
    
    // Popup & Alerts
    @State private var showPopup = false
    @State private var showingDuplicateAlert = false
    @State private var duplicateReceiptId: String?
    @State private var pendingDuplicateReceipt: ReceiptData?
    @State private var pendingDuplicateImage: UIImage?
    
    // Animations
    @State private var isTextVisible = false
    
    // Input
    @State private var chatInputText = ""
    @State private var keyboardHeight: CGFloat = 0
    
    private var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d | HH:mm"
        return formatter.string(from: Date()).uppercased()
    }
    
    var body: some View {
        ZStack {
            // MARK: - 1. Deep Black Background
            // MARK: - 1. Deep Premium Background
            LinearGradient(
                colors: [Color(hex: "0f1c2e"), Color(hex: "02050a")], // Dark Navy -> Almost Black
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // MARK: - 2. Vibrant Gradient Glow (The "Flow")
            gradientBackground
                .ignoresSafeArea()
            
            // MARK: - 3. Grid Lines (Technical Aesthetic)
            // Grid lines removed
            
            // MARK: - 4. Content
            VStack(alignment: .leading, spacing: 0) {
                
                
                Spacer()
                
                // Main Text Content
                VStack(alignment: .leading, spacing: 60) {
                    VStack(spacing: 8) {
                        OwlitLogo(size: 50, animateRainbow: shouldAnimate)
                            .padding(.leading, -4)
                        
                        Text("Owlit AI")
                            .font(.custom("FKGroteskTrial-Bold", size: 40))
                            .tracking(-1.5)
                            .lineSpacing(-5)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .frame(maxWidth: .infinity) // Center the VStack in the parent
                    // Animation Modifiers
                    .opacity(isTextVisible ? 1 : 0)
                    .blur(radius: isTextVisible ? 0 : 10)
                    .offset(y: isTextVisible ? 0 : 20)
                    .onAppear {
                        if shouldAnimate {
                            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                                isTextVisible = true
                            }
                        } else {
                            isTextVisible = true // Instant
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedCurrentDate)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.5)
                        
                        if let user = auth.user, let name = user.bestDisplayName.components(separatedBy: " ").first, !name.isEmpty {
                            Text("Welcome Back, \(name)")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text("Welcome!")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // Graph Area
                    WelcomeLineGraph(shouldAnimate: shouldAnimate)
                        .padding(.vertical, 16)
                    
                    // Button Footer
                    HStack(spacing: 24) {
                        Spacer()
                        
                        // Left Action Button (Camera)
                        Button(action: {
                            showCamera = true
                        }) {
                            Circle()
                                .fill(Color.black) // Black Background
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                )
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }

                        // Center Action Button (Photo Gallery)
                        Button(action: {
                            showPhotoPicker = true
                        }) {
                            Circle()
                                .fill(Color.black) // Black Background
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white.opacity(0.8))
                                )
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        // Right Action Button
                        Button(action: {
                            onContinue()
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color(hex: "E0E0E0")) // Silver White Arrow
                                .frame(width: 56, height: 56) // Matched Camera Button Size
                                .background(Color.black) // Black Background
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5) // Adjusted shadow
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1) // Adjusted stroke for dark button
                                )
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 40) // Reduced from 160 to accommodate graph
                    
                    // Chat Input Field
                    HStack {
                        ZStack(alignment: .leading) {
                            // Custom Gradient Placeholder
                            if chatInputText.isEmpty {
                                Text("Ask Owlit Anything...")
                                    .font(.system(size: 14))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.6)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .allowsHitTesting(false) // Pass touches to TextField
                            }
                            
                            
                            TextField("", text: $chatInputText)
                                .foregroundColor(.white) // Visible typed text
                                .accentColor(.white) // White Cursor
                                .textFieldStyle(.plain) // No system background
                                .font(.system(size: 14))
                                .submitLabel(.send)
                            // Redirect to chat when tapped (but keep text)
                                .onTapGesture {
                                    if !chatInputText.isEmpty {
                                        // If user already typed something, send it?
                                        // The request says: "when user clicks on input box redirect user to chat window and make sure what is typed remain in memory and continus in the chat window"
                                        // This implies just opening the input triggers the transition.
                                        // We will store the text in a global or pass it via callback.
                                        // onAskAI handles "Draft" text if we pass a special flag or just pass the text.
                                        onAskAI?(chatInputText)
                                    } else {
                                        // Just go there
                                        onAskAI?("")
                                    }
                                }
                                .onSubmit {
                                    if !chatInputText.isEmpty {
                                        onAskAI?(chatInputText)
                                    }
                                }
                        }
                        
                        Button(action: {
                            if !chatInputText.isEmpty {
                                onAskAI?(chatInputText)
                            }
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(Color.black)
                                        .shadow(color: .white.opacity(0.1), radius: 2, x: -1, y: -1)
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                                )
                        }
                    }
                    .padding(.vertical, 12) // Slightly taller for 3D feel
                    .padding(.horizontal, 20)
                    .background(
                        ZStack {
                            // 1. Base Glass Layer
                            Color.white.opacity(0.02) // User requested 0.02 level
                                .background(.ultraThinMaterial.opacity(0.2)) // Subtle blur
                            
                            // 2. 3D Bevel/Bump Effect (Rainbow Gradient Border)
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2 // Light thickness
                                )
                        }
                    )
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5) // Lift off surface
                    .padding(.horizontal, 16)
                    .padding(.top, 10) // Spacing below buttons (Almost touching)
                }
                .padding(.vertical, 80)
                .padding(.horizontal, 20)
                .liquidGlass(cornerRadius: 30, hasBorder: false, has3dBump: false) // Border and Bump removed
                .padding(.top, 100) // Significantly increased external padding to prevent truncation
                .padding(.horizontal, 24)
                .padding(.bottom, 30) // Adjusted bottom padding
                .offset(y: -keyboardHeight * 0.4) // Shift up slightly when keyboard appears
            }
            
            // MARK: - 5. Popup Overlay
            if isProcessing {
                ProcessingPopupView(steps: scanningSteps, progress: scanProgress)
                    .zIndex(100)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                handleImageSelection(image)
            }
        }
        .alert("Duplicate Receipt", isPresented: $showingDuplicateAlert) {
            Button("Edit") {
                if var receipt = pendingDuplicateReceipt {
                    receipt.originalImage = pendingDuplicateImage
                    receipt.existingReceiptId = duplicateReceiptId
                    // Handoff to preview
                    ImageTransfer.shared.pendingImage = pendingDuplicateImage
                    self.onScanSuccess?(receipt)
                }
            }
            Button("Replace Existing", role: .destructive) {
                if let receipt = pendingDuplicateReceipt, let image = pendingDuplicateImage {
                    performInstantReplace(receipt: receipt, image: image, existingId: duplicateReceiptId)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDuplicateReceipt = nil
                pendingDuplicateImage = nil
                duplicateReceiptId = nil
            }
        } message: {
            Text("This receipt already exists. Would you like to edit the details, replace the existing record with this scan, or cancel?")
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { image in
                handleImageSelection(image)
            }
        }
        .onTapGesture {
            // Dismiss Keyboard
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        // Keyboard Avoidance
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) {
                    // Provide a bit of extra buffer so it's not glued to the keyboard
                    self.keyboardHeight = keyboardFrame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                self.keyboardHeight = 0
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var gradientBackground: some View {
        ZStack {
            // Main Orange body
            Circle()
                .fill(Color(hex: "FF4500")) // Orange Red
                .frame(width: 400, height: 400)
                .blur(radius: 90)
                .offset(x: 100, y: 250)
            
            // Secondary Gold/Yellow highlight
            Circle()
                .fill(Color(hex: "FFD700")) // Gold
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -50, y: 300)
            
            // Deep Red/Brown undertone
            Circle()
                .fill(Color(hex: "8B0000")) // Dark Red
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: 0, y: 400)
        }
    }
    
    // MARK: - Logic
    
    func handleImageSelection(_ image: UIImage) {
        // Ensure user is authenticated to scan. If not, redirect to Login via onContinue.
        guard let token = auth.token else {
            print("❌ No token available for scanning.")
            onContinue()
            return
        }
        
        isProcessing = true
        scanningSteps = []
        scanProgress = 0.0
        
        // Build Steps
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
         guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
             isProcessing = false
             return
         }
        
        Task {
            // Simulator for Steps (Optimistic Progress)
            var isFinished = false
            Task {
                // Phase 1: Milestones (Up to ~87%)
                for (index, step) in steps.enumerated() {
                    if isFinished { break }
                    
                    // Stop before final step to wait for API
                    if index == steps.count - 1 { break }
                     
                    await MainActor.run {
                        withAnimation { 
                            scanningSteps.append(step) 
                            // Update progress based on steps (0 to ~87%)
                            self.scanProgress = Double(scanningSteps.count) / Double(steps.count)
                        }
                    }
                    
                    let delay = index < 3 ? 0.4 : 0.8 
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                // Phase 2: The "Creep" (88% -> 99%)
                // If API is still working, slowly tick up
                while !isFinished && scanProgress < 0.99 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second wait
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
                
                // REMOVED AUTO-SAVE LOGIC
                // We directly hand off the receipt to the RootView -> ChatView -> CryptoView for review.
                
                // MARK: - Success Handling
                isFinished = true
                receipt.originalImage = resizedImage
                
                // 1. Force Progress to 100% (Visual Closure)
                await MainActor.run {
                    // Ensure all previous steps are present
                    if scanningSteps.count < steps.count - 1 {
                        scanningSteps = Array(steps.dropLast())
                    }
                    // Add Final Step
                    withAnimation {
                        if !scanningSteps.contains(steps.last!) {
                            scanningSteps.append(steps.last!)
                        }
                        self.scanProgress = 1.0 // Snap to 100%
                    }
                }
                
                // 2. Short visual pause so user sees "100%"
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s pause
                
                await MainActor.run {
                    self.isProcessing = false
                    // Handoff
                    print("🚀 WelcomeLandingView: Handoff Receipt. Image: \(receipt.originalImage != nil)")
                    
                    // Singleton Handoff
                    ImageTransfer.shared.pendingImage = resizedImage
                    
                    self.onScanSuccess?(receipt)
                }
            } catch {
                print("❌ Scan failed: \(error)")
                await MainActor.run {
                    isFinished = true
                    self.isProcessing = false
                    self.onContinue()
                }
            }
        }
    }
    
    func performInstantReplace(receipt: ReceiptData, image: UIImage, existingId: String?) {
        guard let token = auth.token else {
            print("❌ No token available for instant replace")
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                var saveParams = ["receiptData": "", "duplicateAction": "replace"]
                
                if let existingId = existingId {
                    saveParams["existingReceiptId"] = existingId
                }
                
                if let jsonData = try? JSONEncoder().encode(receipt),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    saveParams["receiptData"] = jsonString
                }
                
                let imageData = image.jpegData(compressionQuality: 0.6)
                
                let (_, response) = try await APIClient.shared.uploadRequest(
                    path: "/api/receipts",
                    data: imageData,
                    fileName: "receipt.jpg",
                    fieldName: "receiptImage",
                    mimeType: "image/jpeg",
                    parameters: saveParams,
                    token: token
                )
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    await MainActor.run {
                        self.isProcessing = false
                        self.pendingDuplicateReceipt = nil
                        self.pendingDuplicateImage = nil
                        self.duplicateReceiptId = nil
                        // Success - maybe show a success message or just continue
                        print("✅ Receipt replaced successfully")
                    }
                } else {
                    throw NSError(domain: "Network", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to replace receipt"])
                }
            } catch {
                print("❌ Replace failed: \(error)")
                await MainActor.run {
                    self.isProcessing = false
                }
            }
        }
    }
}

// Processing Popup (Duplicated for simplicity to ensure availability in this file context if needed, or rely on shared struct if extracted. Assuming internal here.)
// Processing Popup
struct ProcessingPopupView: View {
    let steps: [String]
    let progress: Double
    
    var body: some View {
        ZStack {
            // 1. Full Screen GIF Background
            GifImage("ScanningAnimation")
                .ignoresSafeArea()
            
            // 2. Gradient Overlay for Readability
            LinearGradient(
                colors: [.black.opacity(0.2), .black.opacity(0.9)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 3. Content Overlay
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 12) {
                    if let activeStep = steps.last {
                         Text(activeStep)
                            .font(.custom("FKGroteskTrial-Regular", size: 14))
                            .foregroundColor(.gray)
                            .transition(.opacity)
                            .id(activeStep)
                    }
                    
                    HStack(spacing: 12) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule()
                                    .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: min(geo.size.width, geo.size.width * progress))
                                    .animation(.spring(), value: progress)
                            }
                        }
                        .frame(height: 4)
                        .frame(width: 150)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .background(Color.black) // Ensure no bleed-through
    }
}

#Preview {
    WelcomeLandingView(onContinue: {})
}

struct WelcomeLineGraph: View {
    var shouldAnimate: Bool = true // Params
    @State private var drawProgress: CGFloat = 0
    
    // Fake Data Points (Normalized 0-1)
    let dataPoints: [CGFloat] = [0.25, 0.85, 0.45, 0.95, 0.4, 0.9, 0.6, 1.0]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            Path { path in
                // Start
                let startY = height * (1 - dataPoints[0])
                path.move(to: CGPoint(x: 0, y: startY))
                
                // Curve through points
                for i in 1..<dataPoints.count {
                    let prevIndex = i - 1
                    let x = width * CGFloat(i) / CGFloat(dataPoints.count - 1)
                    let y = height * (1 - dataPoints[i])
                    
                    let prevX = width * CGFloat(prevIndex) / CGFloat(dataPoints.count - 1)
                    let prevY = height * (1 - dataPoints[prevIndex])
                    
                    let ctrl1 = CGPoint(x: prevX + (x - prevX) * 0.5, y: prevY)
                    let ctrl2 = CGPoint(x: prevX + (x - prevX) * 0.5, y: y)
                    
                    path.addCurve(to: CGPoint(x: x, y: y), control1: ctrl1, control2: ctrl2)
                }
            }
            .trim(from: 0, to: drawProgress)
            .stroke(
                LinearGradient(
                    colors: [Color.green, Color(hex: "DFFF00")], // Money/Growth Colors
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 5)
        }
        .frame(height: 60) // Specific height for the graph strip
        .onAppear {
            if shouldAnimate {
                withAnimation(.easeInOut(duration: 2.0).delay(0.5)) {
                    drawProgress = 1.0
                }
            } else {
                drawProgress = 1.0 // Instant
            }
        }
    }
}

