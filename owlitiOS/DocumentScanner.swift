//
//  DocumentScanner.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 16/12/2025.
//

import SwiftUI
import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    var onScan: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onScan: (UIImage) -> Void
        
        init(onScan: @escaping (UIImage) -> Void) {
            self.onScan = onScan
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            controller.dismiss(animated: true)
            // Process the Scanned Pages
            // For now, just take the first page
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)
                DispatchQueue.main.async {
                    self.onScan(image)
                }
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document Scanner Failed: \(error)")
            controller.dismiss(animated: true)
        }
    }
}
