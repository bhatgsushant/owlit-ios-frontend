import SwiftUI
import Foundation

struct TextFormatter {
    static func format(_ text: String, isDarkMode: Bool = true) -> AttributedString {
        // 1. Clean up Text (Lists)
        var cleanedText = text
        // Replace list markers with Bullet + 2 Spaces (Flush Left)
        cleanedText = cleanedText.replacingOccurrences(of: "(?m)^\\d+\\.\\s", with: "●  ", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: "(?m)^[\\*\\-]\\s", with: "●  ", options: .regularExpression)
        
        // 1b. Linkify Keywords (before bold checking)
        // ... (lines 14-22 unchanged, kept for context match)
        let merchants = ["Alphabet", "Google", "Apple", "Tesco", "Microsoft", "Co-op","Lidl"]
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
            finalAttributed
            += normalPart
            
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
                        finalAttributed[attrRange].foregroundColor = isDarkMode ? .white : .black
                    }
                }
            } catch {
                print("Formatter Regex Error: \(error)")
            }
        }
        
        // 3.5 Highlight Merchant Keywords (Green + Bold + Link)
        // ... (lines 83-103 unchanged)
        if #available(iOS 16.0, *) {
             let merchants = ["Alphabet", "Google", "Apple", "Tesco", "Microsoft", "Co-op", "Lidl", "Aldi", "Asda", "Sainsbury's", "Morrisons", "Waitrose"]
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
                             // Add URL attribute with encoding
                             if let encoded = merchant.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
                                let url = URL(string: "merchant://\(encoded)") {
                                 finalAttributed[attrRange].link = url
                             }
                         }
                     }
                 } catch { }
             }
        }
        
        // 4. Paragraph & Global Style
        var container = AttributeContainer()
        
        // A. Default Paragraph Style (No Indent)
        let defaultParagraphStyle = NSMutableParagraphStyle()
        defaultParagraphStyle.headIndent = 0
        defaultParagraphStyle.firstLineHeadIndent = 0
        defaultParagraphStyle.paragraphSpacing = 16
        defaultParagraphStyle.paragraphSpacingBefore = 4
        defaultParagraphStyle.lineSpacing = 4
        
        // B. List Paragraph Style (Hanging Indent)
        let listParagraphStyle = NSMutableParagraphStyle()
        listParagraphStyle.headIndent = 17 // Indent wrapped lines to align with text (Bullet + 2 Spaces)
        listParagraphStyle.firstLineHeadIndent = 0 // Bullet stays at 0 (Flush Left)
        listParagraphStyle.paragraphSpacing = 16
        listParagraphStyle.paragraphSpacingBefore = 4
        listParagraphStyle.lineSpacing = 4
        
        // No Tab Stops needed for Space separation
        
        // Apply Default Global Style
        container.paragraphStyle = defaultParagraphStyle
        container.foregroundColor = isDarkMode ? Color.white.opacity(0.95) : Color.black.opacity(0.9)
        finalAttributed.mergeAttributes(container, mergePolicy: .keepCurrent)
        
        // 5. Apply List Style to Bullet Points ONLY
        if #available(iOS 16.0, *) {
            do {
                // Match lines starting with Bullet + Space
                let listRegex = try Regex("(?m)^● .*")
                let plainString = String(finalAttributed.characters)
                let matches = plainString.matches(of: listRegex)
                
                for match in matches {
                    if let attrRange = Range(match.range, in: finalAttributed) {
                        finalAttributed[attrRange].paragraphStyle = listParagraphStyle
                    }
                }
            } catch { }
        }
        
        return finalAttributed
    }
}
