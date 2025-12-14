//
//  KeychainHelper.swift
//  owlitiOS
//
//  Created by Sushant Bhat on 14/11/2025.
//

import Foundation
import Security

class KeychainHelper {
    static let standard = KeychainHelper()

    static let service = "owlit-auth"
    static let account = "owlit-token"

    private init() {}

    func save(_ value: String, service: String, account: String) {
        let data = value.data(using: .utf8)!
        
        // Query to find the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // Attributes to update
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        // First, try to update an existing item
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        // If the item does not exist, add it
        if status == errSecItemNotFound {
            // Add the attributes to the query for the add operation
            var addQuery = query
            addQuery[kSecValueData as String] = data
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("❌ Keychain Error: Failed to add item. Status: \(addStatus)")
            }
        } else if status != errSecSuccess {
            print("❌ Keychain Error: Failed to update item. Status: \(status)")
        }
    }

    func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        } else if status != errSecItemNotFound {
            print("❌ Keychain Error: Failed to read item. Status: \(status)")
        }
        return nil
    }

    func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            print("❌ Keychain Error: Failed to delete item. Status: \(status)")
        }
    }
}
