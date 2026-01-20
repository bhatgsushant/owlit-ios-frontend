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
    @State private var pendingReceipt: ReceiptData? // Hand-off data
    @State private var pendingQuestion: String? // Question Hand-off
    
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
                    withAnimation {
                        hasSeenWelcome = true // Proceed to Main App
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
                ChatView(pendingReceipt: $pendingReceipt, pendingQuestion: $pendingQuestion, onNavigateToHome: {
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
    }
    
    private func handleDeepLink(_ url: URL) {
        print("Deeplink received: \(url)")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }

        if components.scheme == "owlit" && components.host == "auth-callback" {
            if let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
                Task { await auth.setTokenAndRefreshUser(token) }
            } else if let fragment = components.fragment,
                      let token = fragment.split(separator: "=").last.map(String.init) {
                Task { await auth.setTokenAndRefreshUser(token) }
            }
        }
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
