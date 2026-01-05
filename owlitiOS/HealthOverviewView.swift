import SwiftUI

struct HealthOverviewView: View {
    // Theme Colors
    private let bgCream = Color(hex: "F7F5F2")
    private let accentLime = Color(hex: "D2F63E") // Vibrant Lime
    private let cardWhite = Color.white
    private let textBlack = Color(hex: "1A1A1A")
    
    var body: some View {
        ZStack {
            bgCream.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // 1. Header
                    headerSection
                    
                    // 2. Upcoming Appointment
                    appointmentBanner
                    
                    // 3. Today's Medication
                    medicationSection
                    
                    // 4. Health Grid
                    healthGridSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            // Profile Image (Placeholder)
            Image(systemName: "person.circle.fill") // Replace with actual image asset if available
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .foregroundColor(.gray.opacity(0.3))
                .overlay(Circle().stroke(Color.gray.opacity(0.1), lineWidth: 1).allowsHitTesting(false))
            

            Spacer()
            
            // Search Button
            Button(action: {}) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundColor(textBlack)
                    .frame(width: 48, height: 48)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            
            // Notification Button
            Button(action: {}) {
                Image(systemName: "bell")
                    .font(.system(size: 20))
                    .foregroundColor(textBlack)
                    .frame(width: 48, height: 48)
                    .background(Color.white)
                    .clipShape(Circle())
            }
        }
    }
    
    private var appointmentBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Health")
                    .font(.custom("FKGroteskTrial-Regular", size: 32))
                    .foregroundColor(textBlack)
                Text("overview")
                    .font(.custom("FKGroteskTrial-Regular", size: 32)) // Maybe Medium/Bold?
                    .foregroundColor(textBlack)
            }
            
            Spacer()
            
            // Appointment Card
            HStack(spacing: 16) {
                VStack(spacing: 0) {
                    Text("13")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textBlack)
                    Text("WED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dr. Minoz")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textBlack)
                    Text("🕒 9:00am")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
    
    private var medicationSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Todays medication")
                    .font(.custom("FKGroteskTrial-Medium", size: 18))
                    .foregroundColor(textBlack)
                Spacer()
                Button("View all >") { }
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            // Medication Card
            HStack(alignment: .top, spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(textBlack)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "pills.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                    
                    // Badge?
                    Circle()
                        .stroke(cardWhite, lineWidth: 2)
                        .background(Circle().fill(textBlack))
                        .frame(width: 20, height: 20)
                        .overlay(Text("30").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
                        .offset(x: 16, y: 16)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sertraline 100mg")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(textBlack)
                        Spacer()
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .foregroundColor(.gray)
                    }
                    
                    Text("Take one tablet once a day")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.bottom, 12)
                    
                    HStack {
                        Text("Due to be taken at")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textBlack)
                        Text("🕒 9:00am")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(textBlack)
                    }
                }
            }
            .padding(20)
            .background(cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
    
    private var healthGridSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("My health")
                    .font(.custom("FKGroteskTrial-Medium", size: 18))
                    .foregroundColor(textBlack)
                Spacer()
                Button("View all >") { }
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            // Grid
            VStack(spacing: 12) {
                // Row 1
                HStack(spacing: 12) {
                    // Blood Pressure
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "drop.fill")
                            Text("Blood pressure")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(textBlack)
                        
                        // Wave Graph Mockup
                        Spacer()
                        WaveShape()
                            .stroke(textBlack, lineWidth: 2)
                            .frame(height: 30)
                        Spacer()
                        
                        Text("102/80")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(textBlack)
                        + Text(" mmHg").font(.system(size: 14)).foregroundColor(.gray)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .background(Color(hex: "EAE8E4")) // Grayish
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    
                    // Heart Rate (Green)
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "heart.fill")
                            Text("Heart rate")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(textBlack)
                        
                        // Wave Graph
                        Spacer()
                        WaveShape()
                            .stroke(textBlack, lineWidth: 2)
                            .frame(height: 30)
                        Spacer()
                        
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("72")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(textBlack)
                            Text("BPM")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(textBlack.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .background(accentLime)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                
                // Row 2
                HStack(spacing: 12) {
                    // Sleep (Green)
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "moon.fill")
                            Text("Sleep")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(textBlack)
                        
                        Spacer()
                        
                        // Bar Chart Mock
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(0..<6) { i in
                                Capsule()
                                    .fill(textBlack)
                                    .frame(width: 4, height: [20, 30, 25, 40, 35, 20][i])
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Spacer()
                        
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("9")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(textBlack)
                            Text("Hours")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(textBlack.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .background(accentLime)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    
                    // Calories
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "flame.fill")
                            Text("Calories")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(textBlack)
                        
                        Spacer()
                        
                        HStack {
                            // Radial Progress
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(textBlack, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                            }
                            .frame(width: 60, height: 60)
                            
                            VStack(alignment: .leading) {
                                Text("342")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(textBlack)
                                Text("Kcal")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .background(Color(hex: "EAE8E4"))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Shapes

struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height / 2))
        
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height / 2),
            control1: CGPoint(x: rect.width * 0.4, y: 0),
            control2: CGPoint(x: rect.width * 0.6, y: rect.height)
        )
        
        return path
    }
}

// Helper for Hex Colors (Removed - duplicate of DesignSystem.swift)


struct HealthOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        HealthOverviewView()
    }
}
