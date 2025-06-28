//
//  KeychainTokenStorage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation
import Security

final class KeychainTokenStorage: TokenStorage {
    private let service = "com.zunlo.app.token"
    private let account = "auth"

    func save(token: Auth) throws {
        let data = try JSONEncoder().encode(token)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary) // Remove any existing
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        var addQuery = query
        addQuery.merge(attributes) { $1 }
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: "Keychain", code: Int(status)) }
    }

    func loadToken() throws -> Auth? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataRef)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = dataRef as? Data else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
        return try JSONDecoder().decode(Auth.self, from: data)
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
