import SwiftUI

// MARK: - Crystal Glass Implementation
// Replicates the high-fidelity "Frosted Glass" aesthetic from the reference image.
// Features: UltraThinMaterial blur, Milky gradient tint, and sharp bright edge highlights.

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var hasBorder: Bool = true
    var has3dBump: Bool = false // New Bump Style
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 1. Main Blur Layer (Frosted Effect)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.thickMaterial) // Heavier blur as requested
                        // Note: Opacity here primarily affects the BACKGROUND color of the material, not the blur amount.
                        // UltraThinMaterial is already translucent.
                        .opacity(0.05)
                    
                    // 2. Milky Reflex Gradient (The "Sheen")
                    // Gives it that physical glass body look (lighter at top-left)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.15), location: 0),
                                    .init(color: .white.opacity(0.05), location: 0.4),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            // 3. Border / Edge Lighting
            // The reference has a distinct white edge that fades out
            .overlay(
                Group {
                    if hasBorder {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.5), location: 0),     // Bright top-left
                                        .init(color: .white.opacity(0.2), location: 0.5),   // Fading mid
                                        .init(color: .white.opacity(0.05), location: 1)     // Subtle bottom-right
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5 // Thin, crisp border
                            )
                    } else if has3dBump {
                         // 3D Bump Style (White -> Clear -> Black)
                         RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.1), .black.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                }
            )
            // 4. Drop Shadow for separation
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 24, hasBorder: Bool = true, has3dBump: Bool = false) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, hasBorder: hasBorder, has3dBump: has3dBump))
    }
}
