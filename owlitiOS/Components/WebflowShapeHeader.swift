import SwiftUI

struct WebflowShapeHeader: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            
            ZStack {
                // Base background (Orange-ish Red)
                LinearGradient(
                    colors: [Color(hex: "FF8C61"), Color(hex: "FF6B4A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Gold Blob (Top Left)
                Circle()
                    .fill(Color(hex: "DBC06E"))
                    .frame(width: w * 0.8)
                    .offset(x: -w * 0.3, y: -h * 0.2)
                    .blur(radius: 30)
                
                // Green Blob (Bottom Right)
                Circle()
                    .fill(Color(hex: "56BFA2")) // Soft Green
                    .frame(width: w * 0.7)
                    .offset(x: w * 0.3, y: h * 0.3)
                    .blur(radius: 20)
                
                // Overlay Gradient to smooth it out
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipped()
    }
}

#Preview {
    WebflowShapeHeader()
        .frame(width: 300, height: 200)
        .cornerRadius(30)
}
