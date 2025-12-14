//
//  ScanHelpers.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 13/11/2025.
//

import SwiftUI
import Lottie
import UIKit
import AVFoundation

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else { return }
        previewLayer.session = session
        previewLayer.frame = uiView.bounds
    }
}

// MARK: - Lottie Animation
struct LottieView: UIViewRepresentable {
    var name: String
    var loopMode: LottieLoopMode = .loop

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let animationView = LottieAnimationView()
        animationView.animation = LottieAnimation.named(name)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.play()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Zoomable Scroll View
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 3.0
        scrollView.minimumZoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.frame = scrollView.bounds
        scrollView.addSubview(hostedView)

        return scrollView
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: self.content))
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = self.content
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
    }
}

// MARK: - Editable Line Item Row
struct EditableLineItemRow: View {
    @Binding var item: ReceiptLineItem
    let currencyCode: String
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Line item name", text: $item.name)
                .font(.playfairDisplay(size: 18))
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
            
            HStack {
                Image(systemName: "sterlingsign")
                    .foregroundStyle(.black.opacity(0.6))
                TextField("0.00", value: $item.price, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.playfairDisplay(size: 18))
                    .foregroundStyle(.black.opacity(0.85))
                    .focused(isFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            
            TextField("1", value: $item.quantity, format: .number)
                .keyboardType(.decimalPad)
                .font(.playfairDisplay(size: 18))
                .foregroundStyle(.black.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
            
            Menu {
                ForEach(ReceiptCategory.allCases) { category in
                    Button(category.rawValue) {
                        item.category = category
                    }
                }
            } label: {
                HStack {
                    Circle()
                        .fill(item.category.color.opacity(0.9))
                        .frame(width: 14, height: 14)
                    Text(item.category.rawValue)
                        .font(.playfairDisplay(size: 16))
                        .foregroundStyle(.black.opacity(0.85))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.black.opacity(0.4))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
