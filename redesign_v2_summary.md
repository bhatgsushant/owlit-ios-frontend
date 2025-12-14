# 🌌 Owlit iOS Redesign: Ethereal Intelligence

I have completely reimagined the app with a futuristic, high-end aesthetic inspired by modern tools like Linear, Arc, and Perplexity.

## 🎨 Design Language: "Aurora"
- **Background**: A living, breathing mesh gradient (Aurora) that shifts slowly, giving the app a "live" feeling.
- **Glassmorphism 2.0**: We moved beyond simple blur to "Ultra Glass" — a multi-layered material with subtle white borders and deep shadows.
- **Typography**: Large, bold, rounded headings paired with clean sans-serif body text.
- **Navigation**: 
  - **Floating Tab Bar**: Gone is the standard iOS tab bar. It's replaced by a floating glass capsule at the bottom.
  - **Custom Nav Bar**: Large, bold titles with custom glass back buttons.

## 📱 Screen-by-Screen Overhaul

### 1. Login (`LoginView`)
- **Hero**: A glowing 3D-style icon with a mesh gradient backing.
- **Form**: A floating glass card that feels weightless.
- **Input**: Minimalist fields that blend into the glass.

### 2. Scan (`ScanView`)
- **Immersive Camera**: The camera now takes up the full screen.
- **Viewfinder**: A holographic-style frame guide.
- **Controls**: Floating glass buttons for shutter and gallery.
- **Preview**: A bottom sheet that slides up with a drag handle, feeling like a native iOS extension.

### 3. Insights (`InsightsView`)
- **Bento Grid**: Stats are organized in a grid of glass cards (Bento box style).
- **Charts**: Custom-built charts using Swift Charts with gradient fills.
- **Typography**: Giant numbers for key metrics to make a statement.

### 4. Chat (`ChatView`)
- **Interface**: Looks like a premium messaging app.
- **Bubbles**: Gradient bubbles for the user, glass bubbles for the AI.
- **Input**: A floating capsule input bar that sits above the tab bar.

### 5. History (`DocumentsView`)
- **List**: Each receipt is a glass card with a subtle scale animation on appear.
- **Overview**: A donut chart at the top to give instant context.

## 🛠️ Technical Changes
- **`DesignSystem.swift`**: Added `AuroraBackground`, `UltraGlassModifier`, and `AppTheme`.
- **`ScanHelpers.swift`**: consolidated all scanning-related helper views (`LottieView`, `ZoomableScrollView`, `CameraPreviewView`).
- **`RootView.swift`**: Implemented the custom navigation logic.

## 🚀 How to Run
1. Open `owlitiOS.xcodeproj`.
2. Run on **iPhone 15 Pro** simulator (or newer) to see the full effect of the mesh gradients and blurs.
3. Enjoy the new "Ethereal" experience!
