//
//  LoginView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    
    // Form State (UI Only)
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    
    // Layout Constants
    private let cardCornerRadius: CGFloat = 30
    
    var body: some View {
        ZStack {
            // 1. Main Background (Soft Blue/Purple Abstract)
            Color(hex: "F0F4F8").ignoresSafeArea() // Base Color
            
            // Abstract Background Shapes (Subtle)
            GeometryReader { geo in
                Circle()
                    .fill(Color(hex: "E0E7FF")) // Pale Indigo
                    .frame(width: geo.size.width * 1.2)
                    .offset(x: -geo.size.width * 0.5, y: -geo.size.height * 0.1)
                    .blur(radius: 60)
                
                Circle()
                    .fill(Color(hex: "E6FFFA")) // Pale Teal
                    .frame(width: geo.size.width)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.6)
                    .blur(radius: 50)
            }
            .ignoresSafeArea()
            
            // 2. Main Card
            ScrollView {
                VStack(spacing: 0) {
                    mainCard
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                        // Add shadow to card
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    
                    // Bottom Controls (if needed per ref image, e.g., the round button?)
                    // The reference has a round refresh icon at bottom right. Added for completeness.
                    HStack {
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.black.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
        }
    }
    
    // MARK: - Card Component
    private var mainCard: some View {
        VStack(spacing: 0) {
            // Header Section (Colorful Graphic)
            ZStack {
                WebflowShapeHeader()
                
                OwlitLogo(size: 90)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.top, 20)
            }
            .frame(height: 220)
            .clipShape(CustomCornerShape(radius: cardCornerRadius, corners: [.topLeft, .topRight]))
            
            // Body Section (White)
            VStack(spacing: 24) {
                
                // Google Button (Pill)
                Button(action: {
                    auth.startWebAuth()
                }) {
                    let googleColors = [
                        Color(red: 66/255, green: 133/255, blue: 244/255), // Blue
                        Color(red: 234/255, green: 67/255, blue: 53/255),  // Red
                        Color(red: 251/255, green: 188/255, blue: 5/255),  // Yellow
                        Color(red: 52/255, green: 168/255, blue: 83/255)   // Green
                    ]
                    let googleGradient = LinearGradient(gradient: Gradient(colors: googleColors), startPoint: .leading, endPoint: .trailing)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill") // Placeholder for Google Icon
                             .resizable()
                             .frame(width: 24, height: 24)
                             .overlay(googleGradient.mask(Image(systemName: "g.circle.fill").resizable()))
                             .foregroundColor(.clear) // Hide original color to show gradient overlay
                        
                        Text("Sign in with Google")
                            .font(.custom("FKGroteskTrial-Medium", size: 16))
                            .foregroundColor(.black.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(googleGradient, lineWidth: 2)
                    )
                }
                
                // Error Message (if any)
                if let error = auth.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // "or" Divider
                HStack {
                    Spacer()
                    Text("or")
                        .font(.custom("FKGroteskTrial-Regular", size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                }
                
                // Form Inputs
                VStack(spacing: 16) {
                    // Names Row
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("First Name")
                                .font(.custom("FKGroteskTrial-Regular", size: 12))
                                .foregroundColor(.gray)
                            CustomTextField(placeholder: "First Name", text: $firstName)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                             Text("Last Name")
                                 .font(.custom("FKGroteskTrial-Regular", size: 12))
                                 .foregroundColor(.gray)
                             CustomTextField(placeholder: "Last Name", text: $lastName)
                        }
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 6) {
                         Text("Email")
                             .font(.custom("FKGroteskTrial-Regular", size: 12))
                             .foregroundColor(.gray)
                         CustomTextField(placeholder: "Email", text: $email)
                    }
                    
                    // Password
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.custom("FKGroteskTrial-Regular", size: 12))
                            .foregroundColor(.gray)
                            
                        HStack {
                            if isPasswordVisible {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                            
                            Button(action: { isPasswordVisible.toggle() }) {
                                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Color(hex: "F5F5F5"))
                        .cornerRadius(8)
                    }
                }
                
                // Create Account Button (Black)
                Button(action: {
                    // No-op for now
                }) {
                    Text("Create account")
                        .font(.custom("FKGroteskTrial-Medium", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .cornerRadius(25)
                }
                
                // Footer Text
                VStack(spacing: 4) {
                    Text("Signing up for a Webflow account means you")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 0) {
                        Text("agree to the ")
                        Text("Privacy Policy").underline()
                        Text(" and ")
                        Text("Terms of Service").underline()
                        Text(".")
                    }
                    .font(.footnote)
                    .foregroundColor(.black)
                }
                .multilineTextAlignment(.center)
                .font(.custom("FKGroteskTrial-Regular", size: 11))
                
                // Login Link
                HStack(spacing: 4) {
                    Text("Have an account?")
                        .foregroundColor(.black)
                    
                    Button("Log in here") {
                         // Action
                    }
                    .foregroundColor(.black)
                    .underline()
                }
                .font(.custom("FKGroteskTrial-Medium", size: 14))
                .padding(.top, 8)
                .padding(.bottom, 12)
                
            }
            .padding(24)
            .background(Color.white)
            // Rounded corners on TOP too, to separate from header
            .clipShape(CustomCornerShape(radius: cardCornerRadius, corners: .allCorners))
            .padding(.top, -30) // Pull up to overlap header
        }
    }
}

// MARK: - Helpers

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Color(hex: "F5F5F5"))
            .cornerRadius(8)
            .font(.custom("FKGroteskTrial-Regular", size: 15))
    }
}

struct CustomCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
