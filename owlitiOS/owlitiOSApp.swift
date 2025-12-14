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
    @StateObject private var receiptStore = ReceiptDataStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(receiptStore)
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
