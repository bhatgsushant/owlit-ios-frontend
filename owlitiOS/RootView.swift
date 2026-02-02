//
//  RootView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI

enum Tab: String, CaseIterable {
    case scan = "viewfinder"
    case history = "clock.arrow.circlepath"
    case insights = "chart.bar.xaxis"
    case chat = "sparkles.rectangle.stack"
    case profile = "person.crop.circle"
    
    var title: String {
        switch self {
        case .scan: return "Scan"
        case .history: return "History"
        case .insights: return "Insights"
        case .chat: return "Ask AI"
        case .profile: return "Profile"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var selectedTab: Tab = .scan
    @State private var hasSeenWelcome = false
    @State private var isLaunching = true
    @State var pendingReceipt: ReceiptData? // Hand-off data
    @State var pendingQuestion: String? // Question Hand-off
    @State var pendingSharedImage: UIImage? // Shared Image Hand-off
    @State private var showReceiptPreview = false // New Preview State
    
    // Animation Control for Return Navigation
    @State private var shouldAnimateWelcome = true
    
    // Hide native tab bar
    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack {
            // Global Background
            AuroraBackground()
                .overlay(Color.black.opacity(0.1)) // Subtle Dim for Card POP
            
            if !hasSeenWelcome {
                WelcomeLandingView(onContinue: {
                    withAnimation {
                        hasSeenWelcome = true
                        shouldAnimateWelcome = true // Next time (if full reset)
                    }
                }, onScanSuccess: { receipt in
                    // Logic when scan completes on Landing Page
                    pendingReceipt = receipt
                    
                    // Proceed directly to ChatView (which handles the preview)
                    withAnimation {
                        hasSeenWelcome = true
                        shouldAnimateWelcome = true 
                    }
                }, onAskAI: { question in
                    // Logic when user asks a question on Landing Page
                    pendingQuestion = question
                    withAnimation {
                        hasSeenWelcome = true
                        shouldAnimateWelcome = true
                    }
                }, shouldAnimate: shouldAnimateWelcome) // Pass Animation State
                .environmentObject(auth) // Ensure Auth is available
                .transition(.opacity)
            } else if auth.isLoading {
                LoadingView()
            } else if auth.isAuthenticated {
                ChatView(pendingReceipt: $pendingReceipt, pendingQuestion: $pendingQuestion, pendingSharedImage: $pendingSharedImage, onNavigateToHome: {
                    // Navigate back to Landing Page
                    shouldAnimateWelcome = false // Disable animation for Instant Load
                    withAnimation {
                        hasSeenWelcome = false
                    }
                })
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: auth.isAuthenticated)
        // Global App Launch Animation (Like iOS Unlock)
        .scaleEffect(isLaunching ? 0.9 : 1.0)
        .opacity(isLaunching ? 0 : 1.0)
        .onAppear {
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.6)) {
                isLaunching = false
            }
            
            // Check for shared images immediately on app launch
            // This handles the case where extension couldn't open URL but set UserDefaults flag
            if let sharedDefaults = UserDefaults(suiteName: "group.com.bhatgsushant.owlit"),
               sharedDefaults.bool(forKey: "shouldOpenAppForShare") {
                print("🔔 App launched with share extension flag, checking for images...")
                sharedDefaults.removeObject(forKey: "shouldOpenAppForShare")
                sharedDefaults.synchronize()
                
                // Small delay to ensure app is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.checkForAnySharedImages()
                }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onChange(of: auth.isAuthenticated) { isAuthenticated in
            if !isAuthenticated {
                // Reset welcome flow when user logs out
                hasSeenWelcome = false
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                print("📱 App became active, checking for shared images...")
                
                // Check if we should open due to share extension
                if let sharedDefaults = UserDefaults(suiteName: "group.com.bhatgsushant.owlit"),
                   sharedDefaults.bool(forKey: "shouldOpenAppForShare") {
                    print("🔔 Share extension flag detected, checking for images...")
                    sharedDefaults.removeObject(forKey: "shouldOpenAppForShare")
                    sharedDefaults.synchronize()
                }
                
                checkForAnySharedImages()
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("Deeplink received: \(url)")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }

        if components.scheme == "owlit" {
            if components.host == "auth-callback" {
                if let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
                    Task { await auth.setTokenAndRefreshUser(token) }
                } else if let fragment = components.fragment,
                          let token = fragment.split(separator: "=").last.map(String.init) {
                    Task { await auth.setTokenAndRefreshUser(token) }
                }
            } else if components.host == "share" {
                // Handle Share Extension Deep Link
                // URL: owlit://share?image=filename.jpg
                if let imageName = components.queryItems?.first(where: { $0.name == "image" })?.value {
                    print("📂 Handle Share: Image Name: \(imageName)")
                    loadSharedImage(named: imageName)
                }
            }
        }
    }
    
    // Watch for Scene Activation to auto-ingest images (Notification Tap fallback)
    @Environment(\.scenePhase) var scenePhase
    
    // Add onChange modifier to the main ZStack
    
    // Load image from App Group Container
    private func loadSharedImage(named fileName: String) {
        let fileManager = FileManager.default
        // IMPORTANT: Must match the group ID used in Xcode
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.bhatgsushant.owlit") {
            // URL decode the filename in case it was encoded
            let decodedFileName = fileName.removingPercentEncoding ?? fileName
            let fileURL = containerURL.appendingPathComponent(decodedFileName)
            print("📂 Attempting to load from: \(fileURL.path)")
            
            if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
                 processLoadedImage(image, url: fileURL)
            } else {
                print("❌ Failed to load image data from App Group container.")
            }
        } else {
            print("❌ Failed to resolve App Group container URL. Check Entitlements.")
        }
    }
    
    // New: Check for ANY relevant files in the directory
    private func checkForAnySharedImages() {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.bhatgsushant.owlit") else { 
            print("❌ Could not access App Group container")
            return 
        }
        
        // First check UserDefaults for pending image (primary method)
        if let sharedDefaults = UserDefaults(suiteName: "group.com.bhatgsushant.owlit"),
           let fileName = sharedDefaults.string(forKey: "pendingSharedImage"),
           let timestamp = sharedDefaults.object(forKey: "pendingSharedImageTimestamp") as? TimeInterval {
            // Only use if it's recent (within last 30 seconds to be safe)
            let age = Date().timeIntervalSince1970 - timestamp
            if age < 30 {
                print("📂 Found pending shared image in UserDefaults: \(fileName) (age: \(String(format: "%.1f", age))s)")
                let fileURL = containerURL.appendingPathComponent(fileName)
                if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
                    print("✅ Successfully loaded image from UserDefaults path")
                    processLoadedImage(image, url: fileURL)
                    // Clear the UserDefaults entry
                    sharedDefaults.removeObject(forKey: "pendingSharedImage")
                    sharedDefaults.removeObject(forKey: "pendingSharedImageTimestamp")
                    sharedDefaults.synchronize()
                    return
                } else {
                    print("⚠️ Image file not found at path: \(fileURL.path)")
                }
            } else {
                print("⚠️ UserDefaults entry too old (\(String(format: "%.1f", age))s), ignoring")
                // Clean up old entry
                sharedDefaults.removeObject(forKey: "pendingSharedImage")
                sharedDefaults.removeObject(forKey: "pendingSharedImageTimestamp")
            }
        }
        
        // Fallback: Check directory for image files (in case UserDefaults wasn't set)
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: [.creationDateKey])
            // Filter for images created by share extension
            // Check for both "shared_image_" (OwlitExt) and "shared_receipt_" (OwlitScan) prefixes
            
            let imageFiles = fileURLs.filter { 
                $0.lastPathComponent.hasPrefix("shared_image_") || 
                $0.lastPathComponent.hasPrefix("shared_receipt_")
            }
            
            // Sort by creation date, newest first
            let sortedFiles = imageFiles.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            
            if let targetFile = sortedFiles.first {
                // Only process if file is recent (within last 30 seconds)
                if let creationDate = try? targetFile.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   Date().timeIntervalSince(creationDate) < 30 {
                    print("📂 Found recent shared file: \(targetFile.lastPathComponent)")
                    if let data = try? Data(contentsOf: targetFile), let image = UIImage(data: data) {
                        processLoadedImage(image, url: targetFile)
                    }
                }
            }
        } catch {
            print("Error checking shared directory: \(error)")
        }
    }
    
    private func processLoadedImage(_ image: UIImage, url: URL) {
        print("✅ Successfully loaded shared image!")
        
        // Trigger flow
        self.pendingSharedImage = image
        
        // Ensure we skip welcome
        if !hasSeenWelcome {
             withAnimation { hasSeenWelcome = true }
        }
        
        // Cleanup file after loading
        try? FileManager.default.removeItem(at: url)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            Text("Preparing workspace...")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(width: 200, height: 200)
        .ultraGlass()
    }
}
