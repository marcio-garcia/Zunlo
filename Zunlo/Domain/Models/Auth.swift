//
//  Auth.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation

struct Auth: Codable, Sendable, Equatable {
    let token: AuthToken?
    let user: User
}

extension Auth {
    static var empty: Auth {
        return Auth(
            token: AuthToken(
                accessToken: "",
                refreshToken: nil,
                expiresAt: Date()
            ),
            user: User(
                id: UUID(),
                email: nil,
                isAnonymous: true)
        )
    }
}

struct AuthToken: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}
