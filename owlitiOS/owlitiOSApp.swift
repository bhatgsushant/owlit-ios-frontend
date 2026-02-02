//
//  owlitiOSApp.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI
import Combine

@main
struct owlitiOSApp: App {
    @StateObject private var authManager = AuthManager()
    
    init() {
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .onOpenURL { url in
                    print("📨 Received deep link URL:", url)
                    
                    // Check if it's a share URL - RootView will handle it
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                       components.scheme == "owlit",
                       components.host == "share" {
                        // Share URLs are handled by RootView's onOpenURL
                        // RootView will receive this via its own onOpenURL handler
                        return
                    }
                    
                    // Forward all other URLs to the AuthManager
                    Task {
                        await authManager.handleAuthCallback(url: url)
                    }
                }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted.")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }
    }
}
