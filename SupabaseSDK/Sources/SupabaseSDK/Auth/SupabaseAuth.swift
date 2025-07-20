//
//  SupabaseAuth.swift
//  SupabaseSDK
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation

public class SupabaseAuth {
    private let config: SupabaseConfig
    private let httpService: NetworkService
    
    public var authToken: String? {
        didSet {
            httpService.authToken = authToken
        }
    }
    
    public init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.httpService = NetworkService(config: config, session: session)
    }
    
    public func signUp(email: String, password: String) async throws -> SBAuth {
        return try await httpService.perform(
            path: "auth/v1/signup",
            method: .post,
            bodyObject: ["email": email, "password": password],
            query: ["grant_type": "password"]
        )
    }

    public func signIn(email: String, password: String) async throws -> SBAuth {
        return try await httpService.perform(
            path: "auth/v1/token",
            method: .post,
            bodyObject: ["email": email, "password": password],
            query: ["grant_type": "password"]
        )
    }
    
    public func refreshSession(refreshToken: String) async throws -> SBAuth {
        return try await httpService.perform(
            path: "auth/v1/token",
            method: .post,
            bodyObject: ["refresh_token": refreshToken],
            query: ["grant_type": "refresh_token"]
        )
    }
    
    public func signInAnonymously() async throws -> SBAuth {
        return try await httpService.performRequest(
            path: "auth/v1/anonymous",
            method: .post
        )
    }

    public func signOut() async throws {
        try await httpService.performRequest(
            path: "auth/v1/logout",
            method: .post
        )
    }

    public func linkIdentityWithMagicLink(email: String) async throws {
        try await httpService.performRequest(
            path: "auth/v1/user/identities",
            method: .post,
            bodyObject: ["email": email, "provider": "email"]
        )
    }
}
