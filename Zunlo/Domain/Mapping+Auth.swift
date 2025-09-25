//
//  Mapping+Auth.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation
//import SupabaseSDK
import Supabase

extension AuthResponse {
    func toDomain() -> AuthSession {
        return AuthSession(
            token: self.session?.toDomain(),
            user: self.user.toDomain()
        )
    }
}

extension Session {
    func toDomain() -> AuthToken {
        return AuthToken(
            accessToken: self.accessToken,
            refreshToken: self.refreshToken,
            expiresAt: Date(timeIntervalSince1970: self.expiresAt))
    }
}

extension Supabase.User {
    func toDomain() -> User {
        return User(
            id: self.id,
            email: self.email,
            isAnonymous: self.isAnonymous
        )
    }
}
