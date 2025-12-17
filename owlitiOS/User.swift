//
//  User.swift
//  owlitiOS
//

import Foundation

struct User: Codable {
    let id: String
    let email: String
    let displayName: String?
    let fullName: String? // New field based on user hint (profiles.full_name)
    let name: String?     // Fallback text
    let avatar: String?
    let provider: String?
    let iat: Int?
    let exp: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case fullName = "full_name"
        case name
        case avatar
        case provider
        case iat
        case exp
    }
    
    /// Returns the best available name for the user.
    var bestDisplayName: String {
        return fullName ?? displayName ?? name ?? "User"
    }
}