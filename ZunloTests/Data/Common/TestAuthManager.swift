//
//  TestAuthManager.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
@testable import Zunlo

// If you have a concrete AuthManager in prod, you can make it conform in app target:
// extension AuthManager: AuthProviding { public var userId: UUID? { user?.id } }

public struct TestAuthManager: AuthProviding {
    public let userId: UUID?
    public var accessToken: String?
    public var authorized: Bool = true
    
    public init(userId: UUID? = UUID()) {
        self.userId = userId
    }
    
    public static func stub(_ id: UUID = UUID()) -> TestAuthManager {
        .init(userId: id)
    }
    
    public func refreshSession(refreshToken: String?) async throws -> AuthToken? {
        AuthToken(accessToken: "", refreshToken: "", expiresAt: Date())
    }
    
    public func isAuthorized() async -> Bool {
        return authorized
    }
}
