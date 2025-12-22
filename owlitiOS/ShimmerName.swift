
import SwiftUI

struct ShimmerName: View {
    var name: String
    @State private var phase: CGFloat = 0
    
    var body: some View {
        Text(name)
            .font(.system(size: 44, weight: .regular, design: .serif))
            .foregroundColor(Color(white: 0.3)) // Base layer
            .overlay(
                Text(name)
                    .font(.system(size: 44, weight: .regular, design: .serif))
                    .foregroundColor(Color(white: 0.7)) // Shine layer
                    .mask(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0.0),
                                        .init(color: .white, location: 0.5),
                                        .init(color: .clear, location: 1.0)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .rotationEffect(.degrees(30)) // Slight angle
                            .offset(x: -200) // Start off-screen
                            .offset(x: phase * 400) // Move across
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
