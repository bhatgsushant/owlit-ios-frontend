
import SwiftUI

struct ShimmerName: View {
    var name: String
    @State private var phase: CGFloat = 0
    
    var body: some View {
        Text(name)
            .font(.system(size: 44, weight: .regular, design: .serif))
            // Base layer: Darker Gray
            .foregroundColor(Color(white: 0.3))
            .overlay(
                // Shimmer layer: Lighter Gray
                GeometryReader { geo in
                    Text(name)
                        .font(.system(size: 44, weight: .regular, design: .serif))
                        .foregroundColor(Color(white: 0.7)) // The "shine" color
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: .clear, location: 0),
                                            .init(color: .white, location: 0.5),
                                            .init(color: .clear, location: 1)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * 1.5)
                                .offset(x: -geo.size.width + (geo.size.width * 3 * phase))
                        )
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
