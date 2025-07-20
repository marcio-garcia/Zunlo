//
//  AuthUserStorage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import Foundation

final class AuthUserStorage: UserStorage {
    private let service = "net.zunlo.app"
    private let account = "user"

    private let keychain: KeychainStorage<User>
    
    init() {
        keychain = KeychainStorage<User>(service: service, account: account)
    }
    
    func save(user: User) throws {
        try keychain.save(user)
    }

    func loadUser() throws -> User? {
        return try keychain.load()
    }

    func clear() throws {
        try keychain.clear()
    }
}
