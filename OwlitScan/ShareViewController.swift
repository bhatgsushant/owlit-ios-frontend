//
//  ShareViewController.swift
//  OwlitScan
//
//  Created by Sushant Bhat on 25/01/2026.
//

//
//  ShareViewController.swift
//  OwlitScan
//
//  Created by OwlIt AI.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private let appGroupId = "group.com.bhatgsushant.owlit"
    
    // UI References
    private let logoImageView = UIImageView()
    private let messageLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPremiumUI()
        handleShare()
    }
    
    private func setupPremiumUI() {
        // Premium dark background with subtle gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0).cgColor,
            UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0).cgColor
        ]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Main container
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Logo Image View
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.contentMode = .scaleAspectFit
        // Try to load logo from assets, fallback to system image
        if let logoImage = UIImage(named: "Owlit Logo") {
            logoImageView.image = logoImage
        } else {
            // Create a simple white circle as fallback
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80))
            logoImageView.image = renderer.image { context in
                context.cgContext.setFillColor(UIColor.white.cgColor)
                context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 80, height: 80))
            }
        }
        containerView.addSubview(logoImageView)
        
        // Message Label with FK Grotesk font
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "Open the Owlit app\nto see your processed image"
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        
        // Try to load FK Grotesk font
        if let fkGroteskFont = UIFont(name: "FKGroteskTrial-Regular", size: 18) {
            messageLabel.font = fkGroteskFont
        } else if let fkGroteskMedium = UIFont(name: "FKGroteskTrial-Medium", size: 18) {
            messageLabel.font = fkGroteskMedium
        } else {
            // Fallback to system font
            messageLabel.font = .systemFont(ofSize: 18, weight: .regular)
        }
        
        // Add subtle letter spacing for premium feel
        let attributedString = NSMutableAttributedString(string: messageLabel.text ?? "")
        attributedString.addAttribute(.kern, value: 0.5, range: NSRange(location: 0, length: attributedString.length))
        messageLabel.attributedText = attributedString
        
        containerView.addSubview(messageLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Container centered
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            
            // Logo
            logoImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            logoImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 32),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Update gradient frame when view layout changes
        view.layoutIfNeeded()
        gradientLayer.frame = view.bounds
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update gradient frame
        if let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = view.bounds
        }
    }

    private func handleShare() {
        // 1. Find the extension item that contains the image
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        // 2. Look for the image provider (public.image)
        let imageType = UTType.image.identifier
        
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(imageType) {
                // 3. Load the item
                provider.loadItem(forTypeIdentifier: imageType, options: nil) { [weak self] (item, error) in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Share Error: \(error)")
                        self.cancel()
                        return
                    }
                    
                    // The item can be a URL, UIImage, or Data
                    self.processItem(item)
                }
                return
            }
        }
        
        // If no image found
        cancel()
    }
    
    private func processItem(_ item: Any?) {
        var imageToSave: UIImage?
        
        if let url = item as? URL {
            // It's a file URL
            if let data = try? Data(contentsOf: url) {
                imageToSave = UIImage(data: data)
            }
        } else if let image = item as? UIImage {
            imageToSave = image
        } else if let data = item as? Data {
            imageToSave = UIImage(data: data)
            // Fix orientation if needed, but usually UIImage(data:) handles it
        }
        
        guard let finalImage = imageToSave else {
            cancel()
            return
        }
        
        saveAndOpenApp(image: finalImage)
    }
    
    private func saveAndOpenApp(image: UIImage) {
        // 1. Prepare file path in App Group
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            print("❌ Critical: Could not access App Group container. Check Entitlements.")
            cancel()
            return
        }
        
        // Simple filename
        let fileName = "shared_receipt_\(Int(Date().timeIntervalSince1970)).jpg"
        let fileURL = containerURL.appendingPathComponent(fileName)
        
        // 2. Save Image as JPEG
        guard let data = image.jpegData(compressionQuality: 0.8) else {
             cancel()
             return
        }
        
        do {
            try data.write(to: fileURL)
            print("✅ Image saved to App Group: \(fileURL.path)")
            
            // Use UserDefaults in App Group to signal the app
            if let sharedDefaults = UserDefaults(suiteName: appGroupId) {
                sharedDefaults.set(fileName, forKey: "pendingSharedImage")
                sharedDefaults.set(Date().timeIntervalSince1970, forKey: "pendingSharedImageTimestamp")
                sharedDefaults.set(true, forKey: "shouldOpenAppForShare")
                sharedDefaults.synchronize()
                print("✅ Saved image filename to UserDefaults: \(fileName)")
            }
            
            // UI is already showing the premium message, just complete after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
            
        } catch {
            print("❌ Failed to write image: \(error)")
            cancel()
        }
    }
    
    private func cancel() {
        self.extensionContext?.cancelRequest(withError: NSError(domain: "ShareError", code: 0, userInfo: nil))
    }
}
