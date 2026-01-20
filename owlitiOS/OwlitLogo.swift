import SwiftUI

struct OwlitLogo: View {
    var size: CGFloat = 80
    var isScanning: Bool = false
    var animateRainbow: Bool = false
    
    var isDarkMode: Bool = true
    
    @State private var isInverted = false
    @State private var rainbowReveal: CGFloat = 0.0 // 0 = White, 1 = Rainbow
    
    // Extracted Face Path for reuse
    private var faceShape: some Shape {
        Path { path in
            // M28 34
            path.move(to: CGPoint(x: 28, y: 34))
            // L64 16
            path.addLine(to: CGPoint(x: 64, y: 16))
            // L100 34
            path.addLine(to: CGPoint(x: 100, y: 34))
            // L100 92
            path.addLine(to: CGPoint(x: 100, y: 92))
            // C100 108 84 116 64 116
            path.addCurve(to: CGPoint(x: 64, y: 116),
                          control1: CGPoint(x: 100, y: 108),
                          control2: CGPoint(x: 84, y: 116))
            // C44 116 28 108 28 92
            path.addCurve(to: CGPoint(x: 28, y: 92),
                          control1: CGPoint(x: 44, y: 116),
                          control2: CGPoint(x: 28, y: 108))
            path.closeSubpath()
        }
    }
    
    var body: some View {
        let faceColor = isInverted ? Color(hex: "DFFF00") : (isDarkMode ? Color.white : Color.black)
        let featureColor = isInverted ? (isDarkMode ? Color.white : Color.black) : (isDarkMode ? Color.black : Color.white)
        
        let rainbowGradient = LinearGradient(
            colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        ZStack {
            // White Face Shape (Composite for animation)
            ZStack {
                // 1. Rainbow Base (Visible when rainbowReveal > 0)
                if animateRainbow {
                    faceShape
                        .fill(rainbowGradient)
                }
                
                // 2. Solid Cover (White/FaceColor)
                // Transitions from Opaque(1.0) -> Transparent(0.0) -> Opaque(1.0)
                faceShape
                    .fill(faceColor)
                    .opacity(animateRainbow ? (1.0 - rainbowReveal) : 1.0)
            }
            
            // Left Eye
            Circle()
                .fill(featureColor)
                .frame(width: 18, height: 18) // r=9 * 2
                .position(x: 48, y: 60)
            
            // Right Eye
            Circle()
                .fill(featureColor)
                .frame(width: 18, height: 18)
                .position(x: 80, y: 60)
            
            // Beak (Triangle)
            Path { path in
                path.move(to: CGPoint(x: 64, y: 72))
                path.addLine(to: CGPoint(x: 56, y: 86))
                path.addLine(to: CGPoint(x: 72, y: 86))
                path.closeSubpath()
            }
            .fill(featureColor)
        }
        // Scale the 128x128 coordinate system to the desired size
        .frame(width: 128, height: 128)
        .scaleEffect(size / 128)
        .frame(width: size, height: size)
        .task(id: isScanning) {
            if isScanning {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                    withAnimation(nil) { // Instant switch, no interpolation
                         isInverted.toggle()
                    }
                }
            } else {
                isInverted = false
            }
        }
        .task {
            // Unconditional task to handle one-off rainbow animation if requested
            if animateRainbow {
                // Initial Delay
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s wait
                
                // Fade to Rainbow
                withAnimation(.linear(duration: 1.5)) {
                    rainbowReveal = 1.0
                }
                
                // Hold Rainbow
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s hold
                
                // Fade back to White
                withAnimation(.easeOut(duration: 1.5)) {
                    rainbowReveal = 0.0
                }
            }
        }
    }
}
