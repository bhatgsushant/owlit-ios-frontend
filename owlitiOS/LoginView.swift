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
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // 🔹 Hero Section
                VStack(spacing: 32) {
                    // Logo with Glow
                    ZStack {
                        OwlitLogo(size: 120)
                            .shadow(color: .white.opacity(0.15), radius: 40, x: 0, y: 0)
                            .shadow(color: .blue.opacity(0.1), radius: 60, x: 0, y: 0)
                    }
                    
                    VStack(spacing: 12) {
                        Text("Owlit AI")
                            .font(.custom("FKGroteskTrial-Medium", size: 32))
                            .foregroundStyle(.white)
                            .tracking(1) // Slight letter spacing
                        
                        Text("Owlit AI Spending Analyst helps to find Insights of your Expenses\nFaster and easier than ever")
                            .font(.custom("FKGroteskTrial-Regular", size: 16))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 80) // Push it up slightly from visual center
                
                // 🔹 Action Area
                VStack(spacing: 24) {
                    // Google Button
                    Button(action: { auth.startWebAuth() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill") // Or generic Apple/Google style icon
                                .font(.system(size: 20))
                            Text("Continue with Google")
                                .font(.custom("FKGroteskTrial-Medium", size: 16))
                        }
                        .foregroundColor(.black)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 32)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .white.opacity(0.1), radius: 20, x: 0, y: 10)
                    }
                    .padding(.horizontal, 40)
                    
                    if let error = auth.lastError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.custom("FKGroteskTrial-Regular", size: 13))
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
                
                // Footer
                Text("Powered by Gemini 1.5 Pro")
                    .font(.custom("FKGroteskTrial-Regular", size: 12))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
        .background(AppTheme.background)
}
