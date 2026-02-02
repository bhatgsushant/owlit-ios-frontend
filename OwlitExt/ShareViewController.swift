//
//  ShareViewController.swift
//  OwlitExt
//
//  Created by OwlIt AI.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupId = "group.com.bhatgsushant.owlit" // MUST match Xcode Capabilities
    private let urlScheme = "owlit://share"

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
        let imageType = UTType.image.identifier
        
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            print("❌ No Input Items")
            return
        }
        
        var found = false
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(imageType) {
                found = true
                provider.loadItem(forTypeIdentifier: imageType, options: nil) { [weak self] (item, error) in
                    if let error = error {
                        print("❌ Share Error: \(error.localizedDescription)")
                        return
                    }
                    self?.processItem(item)
                }
                break // Handle first image only
            }
        }
        
        if !found {
            print("❌ No Image Found")
        }
    }
    
    private func processItem(_ item: Any?) {
        var imageToSave: UIImage?
        
        if let url = item as? URL {
            if let data = try? Data(contentsOf: url) {
                imageToSave = UIImage(data: data)
            }
        } else if let image = item as? UIImage {
            imageToSave = image
        } else if let data = item as? Data {
            imageToSave = UIImage(data: data)
        }
        
        guard let finalImage = imageToSave else {
            print("❌ Could not process image data")
            return
        }
        
        saveAndRedirect(image: finalImage)
    }
    
    private func saveAndRedirect(image: UIImage) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            print("❌ App Group Unavailable")
            return
        }
        
        let fileName = "shared_image_\(Int(Date().timeIntervalSince1970)).jpg"
        let fileURL = containerURL.appendingPathComponent(fileName)
        
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Image Conversion Failed")
            return
        }
        
        do {
            try data.write(to: fileURL)
            print("✅ Image saved to: \(fileURL.path)")
            
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
                self.completeRequest()
            }
            
        } catch {
            print("❌ Save Failed: \(error.localizedDescription)")
        }
    }
    
    private func completeRequest() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}


