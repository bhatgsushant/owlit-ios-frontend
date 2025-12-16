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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .onOpenURL { url in
                    print("📨 Received deep link URL:", url)
                    // Forward all other URLs to the AuthManager
                    Task {
                        await authManager.handleAuthCallback(url: url)
                    }
                }
        }
    }
}
