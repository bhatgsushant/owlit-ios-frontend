//
//  LoginView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Background is handled by RootView, but we can add a specific overlay if needed
            
            VStack {
                Spacer()
                
                // 🔹 Hero Section
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryGradient)
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)
                            .opacity(0.5)
                        
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.5), radius: 20, x: 0, y: 0)
                    }
                    
                    Text("Owlit")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: Color(hex: "6366F1").opacity(0.5), radius: 20, x: 0, y: 10)
                    
                    Text("Financial intelligence,\nreimagined.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 60)
                
                // 🔹 Action Card
                VStack(spacing: 32) {
                    VStack(spacing: 24) {
                        FeatureRow(icon: "sparkles", title: "AI-Native Scanning", description: "Capture receipts with human-level accuracy.")
                        Divider().overlay(Color.white.opacity(0.1))
                        FeatureRow(icon: "chart.bar.xaxis", title: "Deep Analytics", description: "Visualize spending patterns instantly.")
                    }
                    
                    Button(action: { auth.startWebAuth() }) {
                        HStack(spacing: 16) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Continue with Google")
                        }
                    }
                    .buttonStyle(PrimaryGradientButton())
                    
                    if let error = auth.lastError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppTheme.error)
                        .padding()
                        .background(AppTheme.error.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(32)
                .ultraGlass(cornerRadius: 32)
                .padding(.horizontal, 24)
                
                Spacer()
                
                Text("Powered by Gemini 1.5 Pro")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.bottom, 40)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.accentGradient)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
        .background(AppTheme.background)
}
