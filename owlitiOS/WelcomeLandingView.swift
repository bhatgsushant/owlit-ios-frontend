
import SwiftUI

struct WelcomeLandingView: View {
    var onContinue: () -> Void
    
    var body: some View {
        ZStack {
            // MARK: - 1. Deep Black Background
            Color.black.ignoresSafeArea()
            
            // MARK: - 2. Vibrant Gradient Glow (The "Flow")
            // Simulating the amorphous gradient from the reference
            ZStack {
                // Main Orange/Red body
                Circle()
                    .fill(Color(hex: "FF4500")) // OrangeRed
                    .frame(width: 400, height: 400)
                    .blur(radius: 90)
                    .offset(x: 100, y: 250)
                
                // Secondary Yellow/Orange highlight
                Circle()
                    .fill(Color(hex: "FF8C00")) // DarkOrange
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -50, y: 300)
                
                // Deep Red/Purple undertone
                Circle()
                    .fill(Color(hex: "8B0000")) // DarkRed
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: 0, y: 400)
            }
            .ignoresSafeArea()
            
            // MARK: - 3. Grid Lines (Technical Aesthetic)
            GeometryReader { geo in
                ZStack {
                    // Vertical Line
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: geo.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    
                    // Horizontal Line
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: geo.size.width, height: 1)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.35)
                    
                    // Decorative Cross Intersection Glow
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .thin))
                        .foregroundColor(.white.opacity(0.3))
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.35)
                }
            }
            .ignoresSafeArea()
            
            // MARK: - 4. Content
            VStack(alignment: .leading, spacing: 0) {
                

                
                Spacer()
                
                // Main Text Content
                VStack(alignment: .leading, spacing: 16) {
                    Text("Welcome")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Mixed Styling for specific emphasis
                    Group {
                        Text("Explore the ")
                            .foregroundColor(.white.opacity(0.5)) +
                        Text("Owlit")
                            .foregroundColor(.white) +
                        Text(" AI to Sort Your Spendings")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .font(.system(size: 38, weight: .medium, design: .default)) // Crystal clear system font
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                
                // Button Footer
                HStack {
                    // Left element (Eye/Sun icon from reference)
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 56, height: 56)
                        .overlay(
                            OwlitLogo(size: 56)
                                .opacity(0.5)
                        )
                    
                    Spacer()
                    
                    // Right Action Button
                    Button(action: {
                        onContinue()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color.black) // Dark icon on white button
                            .frame(width: 64, height: 64)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .orange.opacity(0.3), radius: 15, x: 0, y: 5)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
    }
}

#Preview {
    WelcomeLandingView(onContinue: {})
}
