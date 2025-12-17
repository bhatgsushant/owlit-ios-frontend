import SwiftUI

struct OwlitLogo: View {
    var size: CGFloat = 80
    
    var body: some View {
        ZStack {
            // White Face Shape
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
            .fill(Color.white)
            
            // Left Eye
            Circle()
                .fill(Color.black)
                .frame(width: 18, height: 18) // r=9 * 2
                .position(x: 48, y: 60)
            
            // Right Eye
            Circle()
                .fill(Color.black)
                .frame(width: 18, height: 18)
                .position(x: 80, y: 60)
            
            // Beak (Triangle)
            Path { path in
                path.move(to: CGPoint(x: 64, y: 72))
                path.addLine(to: CGPoint(x: 56, y: 86))
                path.addLine(to: CGPoint(x: 72, y: 86))
                path.closeSubpath()
            }
            .fill(Color.black)
        }
        // Scale the 128x128 coordinate system to the desired size
        .frame(width: 128, height: 128)
        .scaleEffect(size / 128)
        .frame(width: size, height: size)
    }
}
