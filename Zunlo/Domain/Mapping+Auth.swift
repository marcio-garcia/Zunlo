//
//  Mapping+Auth.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import SupabaseSDK

extension SBAuth {
    func toDomain() -> Auth {
        return Auth(accessToken: self.accessToken,
                    user: self.user.toDomain())
    }
}

extension SBUser {
    func toDomain() -> User {
        return User(id: self.id,
                    email: self.email)
    }
}
