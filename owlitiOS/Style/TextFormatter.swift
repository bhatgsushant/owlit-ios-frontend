import SwiftUI
import Foundation

struct TextFormatter {
    static func format(_ text: String) -> AttributedString {
        // 1. Clean up Text (Lists)
        var cleanedText = text
        // Replace list markers with Bullet + Tab
        cleanedText = cleanedText.replacingOccurrences(of: "(?m)^\\d+\\.\\s", with: "●\t", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: "(?m)^[\\*\\-]\\s", with: "●\t", options: .regularExpression)
        
        // 1b. Linkify Keywords (before bold checking)
        // Note: Doing this at string level is simpler than AttributedString for the link logic
        let merchants = ["Alphabet", "Google", "Apple", "Tesco", "Microsoft", "Co-op"]
        for merchant in merchants {
            // Regex to match whole word, case insensitive
            let pattern = "(?i)\\b(\(merchant))\\b"
            // Replace with custom markdown link syntax we can parse or attribute later?
            // Actually, AttributedString can parse markdown. Let's try inserting a custom marker we can detect below.
            // Or simpler: We can just detect this specific regex during the attribute pass.
        }
        
        // 2. Build AttributedString with Bold Parsing (**text**)
        var currentText = cleanedText
        var finalAttributed = AttributedString()
        
        // We manually parse ** pattern using standard String ranges replacement
        while let range = currentText.range(of: "\\*\\*(.*?)\\*\\*", options: .regularExpression) {
            // A. Text Before match
            let before = currentText[..<range.lowerBound]
            var normalPart = AttributedString(String(before))
            normalPart.font = .custom("FKGroteskTrial-Regular", size: 15)
            finalAttributed += normalPart
            
            // B. Content inside ** **
            let match = currentText[range]
            // Safe index calculation
            if match.count >= 4 {
                let contentStart = match.index(match.startIndex, offsetBy: 2)
                let contentEnd = match.index(match.endIndex, offsetBy: -2)
                let content = match[contentStart..<contentEnd]
                
                var boldPart = AttributedString(String(content))
                boldPart.font = .custom("FKGroteskTrial-Medium", size: 15)
                finalAttributed += boldPart
            } else {
                finalAttributed += AttributedString(String(match))
            }
            
            // C. Advance
            currentText = String(currentText[range.upperBound...])
        }
        
        // Append remaining text
        var remainingPart = AttributedString(currentText)
        remainingPart.font = .custom("FKGroteskTrial-Regular", size: 15)
        finalAttributed += remainingPart
        
        // 3. Highlight Numbers & Currency
        if #available(iOS 16.0, *) {
            do {
                // Regex for Currency Only (Require symbol)
                let numberRegex = try Regex("[$£€][0-9,.]+")
                
                // Get Plain String view to find matches
                let plainString = String(finalAttributed.characters)
                let matches = plainString.matches(of: numberRegex)
                
                for match in matches {
                    // Convert String Range to AttributedString Range
                    if let attrRange = Range(match.range, in: finalAttributed) {
                        finalAttributed[attrRange].font = .system(size: 15, weight: .bold, design: .monospaced)
                        finalAttributed[attrRange].foregroundColor = .white
                    }
                }
            } catch {
                print("Formatter Regex Error: \(error)")
            }
        }
        
        // 3.5 Highlight Merchant Keywords (Green + Bold + Link)
        // We do this after regex to layer on top
        if #available(iOS 16.0, *) {
             let merchants = ["Alphabet", "Google", "Apple", "Tesco", "Microsoft", "Co-op"]
             for merchant in merchants {
                 do {
                     let regex = try Regex("(?i)\\b\(merchant)\\b")
                     let plainString = String(finalAttributed.characters)
                     let matches = plainString.matches(of: regex)
                     
                     // Only link the first occurrence
                     if let match = matches.first {
                         if let attrRange = Range(match.range, in: finalAttributed) {
                             finalAttributed[attrRange].font = .custom("FKGroteskTrial-Regular", size: 15) // Match Body Font
                             // #20808D -> R:32, G:128, B:141
                             finalAttributed[attrRange].foregroundColor = Color(red: 32/255, green: 128/255, blue: 141/255)
                             // Add URL attribute
                             finalAttributed[attrRange].link = URL(string: "merchant://\(merchant)")
                         }
                     }
                 } catch { }
             }
        }
        
        // 4. Paragraph & Global Style
        var container = AttributeContainer()
        
        // Paragraph Style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 35 // Hanging indent
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.paragraphSpacing = 16
        paragraphStyle.paragraphSpacingBefore = 4
        paragraphStyle.lineSpacing = 4 
        
        let tabStop = NSTextTab(textAlignment: .left, location: 35, options: [:])
        paragraphStyle.tabStops = [tabStop]
        paragraphStyle.defaultTabInterval = 35
        
        container.paragraphStyle = paragraphStyle
        container.foregroundColor = .white.opacity(0.95) // Base color
        
        finalAttributed.mergeAttributes(container, mergePolicy: .keepCurrent)
        
        return finalAttributed
    }
}
