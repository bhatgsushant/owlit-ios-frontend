//
//  ProfileView.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var receiptStore: ReceiptDataStore
    @State private var familyName: String = ""

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(proxy.size.width * 0.9, 720)
            
            ZStack {
                gradientBackground
                
                ScrollView(showsIndicators: false) {
                    VStack {
                        Spacer(minLength: 40)
                        profileCard(width: cardWidth)
                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var gradientBackground: some View {
        ZStack {
            Image("ProfileGradient")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(Color.black.opacity(0.35))
            
            LinearGradient(
                colors: [
                    .black.opacity(0.25),
                    .clear,
                    .black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func profileCard(width: CGFloat) -> some View {
        let userName = (auth.user?.displayName?.isEmpty == false ? auth.user?.displayName : nil) ?? "Sushant Bhat"
        let email = auth.user?.email ?? "engg.sushant@gmail.com"
        let inviteCode = formattedInviteCode(from: auth.user?.id)
        let familyId = auth.user?.id ?? "29575bob-ec6a-4ded-906c-48313b3800f8"
        
        VStack(spacing: 22) {
            avatarSection
            
            VStack(spacing: 6) {
                Text(userName)
                    .font(.playfairDisplayBold(size: 30))
                    .foregroundStyle(.white)
                
                Text(email)
                    .font(.playfairDisplay(size: 18))
                    .foregroundStyle(.white)
                    .opacity(0.9)
            }
            
            statsRow(members: 1, invites: 1, families: 1)
            
            HStack(spacing: 18) {
                Button("Join") { }
                    .buttonStyle(GlassCapsuleButton())
                Button("Create") { }
                    .buttonStyle(GlassCapsuleButton())
            }
            
            VStack(spacing: 12) {
                TextField("Family name", text: $familyName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
                    .font(.playfairDisplay(size: 18))
                
                Button("Create family") { }
                    .buttonStyle(GradientPillButton())
            }
            
            VStack(spacing: 12) {
                Text("INVITE CODE")
                    .font(.playfairDisplaySemibold(size: 16))
                    .foregroundStyle(.white.opacity(0.9))
                
                Text(inviteCode)
                    .font(.playfairDisplayBold(size: 22))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 16) {
                Button("Copy") { }
                    .buttonStyle(GlassCapsuleButton())
                Button("New code") { }
                    .buttonStyle(SolidGreenButton())
                Button("Leave") { auth.logout() }
                    .buttonStyle(GlassCapsuleButton(borderColor: Color(red: 0.95, green: 0.55, blue: 0.55)))
            }
            
            Text("Family ID: \(familyId)")
                .font(.playfairDisplay(size: 16))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 28)
        .frame(maxWidth: width)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 26, x: 0, y: 18)
    }

    private var avatarSection: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 150, height: 150)
                    .blur(radius: 16)
                
                AsyncImage(url: auth.user?.avatarURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().tint(.white)
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "person.fill")
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 156, height: 156)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 4)
                )
                
                Text("Upload")
                    .font(.playfairDisplay(size: 14))
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
                    .offset(y: 18)
            }
        }
    }

    private func statsRow(members: Int, invites: Int, families: Int) -> some View {
        HStack(spacing: 18) {
            statItem(title: "Members", value: "\(members)")
            statItem(title: "Invites", value: "\(invites)")
            statItem(title: "Families", value: "\(families)")
        }
        .frame(maxWidth: .infinity)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.playfairDisplayBold(size: 22))
                .foregroundStyle(.white)
            Text(title.uppercased())
                .font(.playfairDisplaySemibold(size: 16))
                .foregroundStyle(.white.opacity(0.95))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func formattedInviteCode(from id: String?) -> String {
        guard let id, !id.isEmpty else { return "DJZEQCQL" }
        let prefix = id.prefix(8).uppercased()
        return String(prefix)
    }
}

struct TranslucentCapsuleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.playfairDisplaySemibold(size: 16))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(configuration.isPressed ? 0.2 : 0.16))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.48), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GlassCapsuleButton: ButtonStyle {
    var borderColor: Color = .white
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.playfairDisplaySemibold(size: 22))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(configuration.isPressed ? 0.18 : 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor.opacity(0.8), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GradientPillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.playfairDisplayBold(size: 22))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.0, green: 0.68, blue: 0.75), Color(red: 0.0, green: 0.72, blue: 0.48)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SolidGreenButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.playfairDisplaySemibold(size: 18))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(configuration.isPressed ? 0.9 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(ReceiptDataStore())
        .background(AppTheme.background)
}
