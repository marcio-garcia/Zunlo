//
//  Mapping+Auth.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation
import SupabaseSDK
import Supabase

//extension SBAuth {
//    func toDomain() -> Auth {
//        return Auth(token: AuthToken(accessToken: self.accessToken,
//                                     refreshToken: self.refreshToken,
//                                     expiresAt: expiresAt),
//                    user: self.user.toDomain())
//    }
//}
//
//extension SBUser {
//    func toDomain() -> User {
//        return User(
//            id: self.id,
//            email: self.email,
//            isAnonymous: self.isAnonymous
//        )
//    }
//}

extension AuthResponse {
    func toDomain() -> Auth {
        let user = User(
            id: self.user.id,
            email: self.user.email,
            isAnonymous: self.user.isAnonymous
        )
        return Auth(
            token: self.session?.toDomain(),
            user: user
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
