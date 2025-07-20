//
//  AuthTokenStorage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation

final class AuthTokenStorage: TokenStorage {
    private let service = "net.zunlo.app"
    private let account = "auth"

    private let keychain: KeychainStorage<AuthToken>
    
    init() {
        keychain = KeychainStorage<AuthToken>(service: service, account: account)
    }
    
    func save(authToken: AuthToken) throws {
        try keychain.save(authToken)
    }

    func loadToken() throws -> AuthToken? {
        return try keychain.load()
    }

    func clear() throws {
        try keychain.clear()
    }
}
