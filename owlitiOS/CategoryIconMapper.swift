//
//  CategoryIconMapper.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 16/12/2025.
//

import SwiftUI

struct CategoryIconMapper {
    
    static func view(for category: String) -> AnyView {
        let name = icon(for: category)
        let col = color(for: category)
        
        return AnyView(
            Image(systemName: name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundColor(col)
        )
    }

    // "OpenAI" generated mapping for common receipt categories to SF Symbols
    static func icon(for category: String?) -> String {
        guard let category = category?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty else {
            return "tag.fill" // Generic tag for unknown/empty
        }
        
        let c = category
        
        // Food & Grocery
        if c.contains("grocery") || c.contains("food") { return "cart.fill" }
        if c.contains("fruit") || c.contains("vegetable") || c.contains("produce") || c.contains("fresh") { return "carrot.fill" }
        if c.contains("meat") || c.contains("beef") || c.contains("chicken") || c.contains("pork") || c.contains("fish") { return "fork.knife" }
        if c.contains("dairy") || c.contains("milk") || c.contains("cheese") || c.contains("yogurt") { return "drop.fill" }
        if c.contains("bread") || c.contains("bakery") || c.contains("bagel") { return "birthday.cake.fill" }
        if c.contains("frozen") || c.contains("ice") { return "snowflake" }
        if c.contains("snack") || c.contains("chip") || c.contains("chocolate") || c.contains("candy") { return "popcorn.fill" }
        if c.contains("beverage") || c.contains("drink") || c.contains("water") || c.contains("juice") || c.contains("soda") { return "mug.fill" }
        if c.contains("alcohol") || c.contains("beer") || c.contains("wine") || c.contains("liquor") || c.contains("spirit") { return "wineglass.fill" }
        
        // Home & Living
        if c.contains("home") || c.contains("household") { return "house.fill" }
        if c.contains("kitchen") || c.contains("cook") { return "frying.pan.fill" }
        if c.contains("clean") || c.contains("laundry") || c.contains("detergent") { return "bubbles.and.sparkles.fill" }
        if c.contains("toilet") || c.contains("paper") || c.contains("tissue") { return "scroll.fill" }
        if c.contains("pet") || c.contains("dog") || c.contains("cat") { return "pawprint.fill" }
        if c.contains("garden") || c.contains("flower") || c.contains("plant") { return "leaf.fill" }
        
        // Health & Beauty
        if c.contains("health") || c.contains("medicine") || c.contains("pharmacy") || c.contains("drug") { return "cross.case.fill" }
        if c.contains("beauty") || c.contains("cosmetic") || c.contains("skin") || c.contains("hair") { return "sparkles" }
        
        // Tech & Electronics
        if c.contains("electronic") || c.contains("tech") || c.contains("computer") { return "desktopcomputer" }
        if c.contains("phone") || c.contains("mobile") { return "iphone" }
        if c.contains("game") || c.contains("toy") { return "gamecontroller.fill" }
        
        // Transport & Auto
        if c.contains("fuel") || c.contains("gas") || c.contains("petrol") { return "fuelpump.fill" }
        if c.contains("car") || c.contains("auto") || c.contains("parking") || c.contains("transport") { return "car.fill" }
        
        // Dining Out
        if c.contains("restaurant") || c.contains("dining") || c.contains("cafe") { return "cup.and.saucer.fill" }
        if c.contains("fast food") || c.contains("burger") || c.contains("pizza") { return "takeoutbag.and.cup.and.straw.fill" }
        
        // Apparel
        if c.contains("cloth") || c.contains("wear") || c.contains("shoe") || c.contains("shirt") { return "tshirt.fill" }
        
        // Misc
        if c.contains("gift") { return "gift.fill" }
        if c.contains("tax") || c.contains("fee") { return "banknote.fill" }
        if c.contains("office") { return "paperclip" }
        
        return "tag.fill"
    }
    
    static func color(for category: String?) -> Color {
        guard let category = category?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty else {
            return .gray
        }
        let c = category
        
        // Vibrant Colors
        if c.contains("grocery") || c.contains("food") { return .green }
        if c.contains("fruit") || c.contains("vegetable") { return .orange }
        if c.contains("meat") || c.contains("beef") { return .red } // Meat red
        if c.contains("dairy") || c.contains("water") || c.contains("frozen") { return .blue } // Cool blue
        if c.contains("bread") || c.contains("bakery") { return .brown } // Warm brown
        if c.contains("alcohol") || c.contains("wine") || c.contains("beer") { return .purple } // Elegant purple
        if c.contains("snack") || c.contains("candy") { return .pink } // Fun pink
        
        if c.contains("home") || c.contains("clean") { return .mint }
        if c.contains("health") || c.contains("medicine") { return .teal }
        if c.contains("fuel") || c.contains("gas") { return .yellow }
        
        if c.contains("tech") || c.contains("electronic") { return .indigo }
        if c.contains("game") { return .purple }
        
        if c.contains("restaurant") || c.contains("cafe") { return .orange }
        
        return .cyan // Default vibrant fallback
    }
}
