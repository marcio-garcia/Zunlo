//
//  Mapping+Auth.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation
import SupabaseSDK

extension SBAuth {
    func toDomain() -> Auth {
//        let expiresAt = Date.isoFormatter.date(from: self.expiresAt) ?? Date()
        return Auth(token: AuthToken(accessToken: self.accessToken,
                                     refreshToken: self.refreshToken,
                                     expiresAt: expiresAt),
                    user: self.user.toDomain())
    }
}

extension SBUser {
    func toDomain() -> User {
        return User(
            id: self.id,
            email: self.email,
            isAnonymous: self.isAnonymous
        )
    }
}
