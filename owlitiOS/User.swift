//
//  User.swift
//  owlitiOS
//

import Foundation

struct User: Codable {
    let id: String
    let email: String
    let displayName: String?
    let avatar: String?
    let provider: String?
    let iat: Int?
    let exp: Int?
}