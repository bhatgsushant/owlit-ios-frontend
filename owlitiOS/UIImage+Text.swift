//
//  UIImage+Text.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 16/12/2025.
//

import UIKit

extension UIImage {
    static func from(text: String) -> UIImage? {
        let nsString = text as NSString
        let font = UIFont.systemFont(ofSize: 20)
        let textColor = UIColor.black
        let attributes = [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: textColor]
        
        // Calculate size
        let maxWidth: CGFloat = 800
        let boundingRect = nsString.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                                 options: .usesLineFragmentOrigin,
                                                 attributes: attributes,
                                                 context: nil)
        
        let size = CGSize(width: ceil(boundingRect.width) + 40, height: ceil(boundingRect.height) + 40)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            nsString.draw(in: CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40),
                          withAttributes: attributes)
        }
    }
}
