//
//  UIImage+Extensions.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 16/12/2025.
//

import UIKit

extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let size = self.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            let width = min(size.width, maxDimension)
            newSize = CGSize(width: width, height: width / aspectRatio)
        } else {
            let height = min(size.height, maxDimension)
            newSize = CGSize(width: height * aspectRatio, height: height)
        }
        
        // If the image is already smaller, return self
        if size.width <= maxDimension && size.height <= maxDimension {
            return self
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
