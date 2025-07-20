//
//  KeychainStorage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import Foundation
import Security

final class KeychainStorage<T: Codable> {
    private let service: String
    private let account: String

    init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    func save(_ object: T) throws {
        let data = try JSONEncoder().encode(object)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary) // Remove any existing item
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        var addQuery = query
        addQuery.merge(attributes) { $1 }
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "Keychain", code: Int(status), userInfo: nil)
        }
    }

    func load() throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataRef)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = dataRef as? Data else {
            throw NSError(domain: "Keychain", code: Int(status), userInfo: nil)
        }
        return try JSONDecoder().decode(T.self, from: data)
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
