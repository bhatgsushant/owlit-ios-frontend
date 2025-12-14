import SwiftUI
import UIKit

// MARK: - 🎨 App Theme & Colors
enum AppTheme {
    // A sophisticated, deep palette
    static let background = Color(hex: "05050A") // Almost black
    static let surface = Color(hex: "12121A") // Dark grey-blue
    
    // Brand Gradients
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], // Indigo to Violet
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "06B6D4"), Color(hex: "3B82F6")], // Cyan to Blue
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Semantic Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "94A3B8") // Slate 400
    static let textTertiary = Color(hex: "64748B") // Slate 500
    
    static let success = Color(hex: "10B981") // Emerald
    static let warning = Color(hex: "F59E0B") // Amber
    static let error = Color(hex: "EF4444") // Red
    
    // Glass Effect
    static let glassStroke = LinearGradient(
        colors: [.white.opacity(0.2), .white.opacity(0.02)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 🌫️ Advanced Glassmorphism
struct UltraGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.03)) // Subtle tint
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.glassStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func ultraGlass(cornerRadius: CGFloat = 24) -> some View {
        modifier(UltraGlassModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - 🌌 Aurora Mesh Background
struct AuroraBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            GeometryReader { proxy in
                let size = proxy.size
                
                ZStack {
                    // Orb 1 - Indigo
                    Circle()
                        .fill(Color(hex: "4F46E5").opacity(0.4))
                        .frame(width: size.width * 0.8)
                        .blur(radius: 80)
                        .offset(x: animate ? -50 : 50, y: animate ? -50 : 50)
                    
                    // Orb 2 - Violet
                    Circle()
                        .fill(Color(hex: "7C3AED").opacity(0.3))
                        .frame(width: size.width * 0.7)
                        .blur(radius: 70)
                        .offset(x: animate ? 100 : -20, y: animate ? 100 : -50)
                    
                    // Orb 3 - Cyan
                    Circle()
                        .fill(Color(hex: "06B6D4").opacity(0.2))
                        .frame(width: size.width * 0.6)
                        .blur(radius: 60)
                        .offset(x: animate ? -30 : 80, y: animate ? 150 : 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                        animate.toggle()
                    }
                }
            }
        }
    }
}

// MARK: - 🔘 Modern Buttons
struct BouncyButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct PrimaryGradientButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color(hex: "6366F1").opacity(0.4), radius: 15, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 🧩 Custom Navigation Bar
struct CustomNavBar: View {
    let title: String
    var showBackButton: Bool = false
    var onBack: (() -> Void)? = nil
    var trailingAction: (() -> Void)? = nil
    var trailingIcon: String? = nil
    
    var body: some View {
        HStack {
            if showBackButton {
                Button(action: { onBack?() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            if let icon = trailingIcon, let action = trailingAction {
                Button(action: action) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60) // Safe area top
        .padding(.bottom, 20)
    }
}

// MARK: - 🔤 Custom Fonts
extension Font {
    static func playfairDisplay(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let font = UIFont(name: "PlayfairDisplay-Regular", size: size) {
            return Font(font)
        }
        return Font.system(size: size, design: .serif).weight(weight)
    }
    
    static func playfairDisplayBold(size: CGFloat) -> Font {
        if let font = UIFont(name: "PlayfairDisplay-Bold", size: size) {
            return Font(font)
        }
        return Font.system(size: size, design: .serif).weight(.bold)
    }
    
    static func playfairDisplaySemibold(size: CGFloat) -> Font {
        if let font = UIFont(name: "PlayfairDisplay-SemiBold", size: size) {
            return Font(font)
        }
        return Font.system(size: size, design: .serif).weight(.semibold)
    }
    
    static func ubuntu(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let font = UIFont(name: "Ubuntu-Regular", size: size) {
            return Font(font)
        }
        return Font.system(size: size, design: .default).weight(weight)
    }
    
    static func ubuntuBold(size: CGFloat) -> Font {
        if let font = UIFont(name: "Ubuntu-Bold", size: size) {
            return Font(font)
        }
        return Font.system(size: size, design: .default).weight(.bold)
    }
    
    static func ubuntuMedium(size: CGFloat) -> Font {
        if let font = UIFont(name: "Ubuntu-Medium", size: size) {
            return Font(font)
        }
        return Font.system(size: size, design: .default).weight(.medium)
    }
}

// MARK: - 🛠️ Utilities
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
