//
//  AuthRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import SwiftUI
import SwiftData
import Supabase

protocol AuthServicing {
    func signUp(email: String, password: String) async throws -> Auth
    func signIn(email: String, password: String) async throws -> AuthToken
    func refreshToken(_ refreshToken: String) async throws -> AuthToken
    func validateToken(_ token: AuthToken) -> Bool
    func signOut() async throws
    func signInAnonymously() async throws -> AuthToken
    func linkIdentityWithMagicLink(email: String) async throws
    func getUser(jwt: String?) async throws -> User
}

class AuthService: AuthServicing {
    
    private var supabase: SupabaseClient!
    
    init(envConfig: EnvConfig) {
        guard let url = URL(string: envConfig.apiBaseUrl) else { return }
        supabase = SupabaseClient(supabaseURL: url,
                                  supabaseKey: envConfig.apiKey)
    }
    
    func signUp(email: String, password: String) async throws -> Auth {
        let authResponse = try await supabase.auth.signUp(email: email, password: password)
        return authResponse.toDomain()
    }
    
    func signIn(email: String, password: String) async throws -> AuthToken {
        let session = try await supabase.auth.signIn(email: email, password: password)
        return session.toDomain()
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        let session = try await supabase.auth.refreshSession(refreshToken: refreshToken)
        return session.toDomain()
    }
    
    func validateToken(_ token: AuthToken) -> Bool {
        return !token.accessToken.isEmpty && token.expiresAt > Date()
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    func signInAnonymously() async throws -> AuthToken {
        let session = try await supabase.auth.signInAnonymously()
        return session.toDomain()
    }
    
    func linkIdentityWithMagicLink(email: String) async throws {
//        try await supabase.auth.linkIdentityWithMagicLink(email: email)
    }
    
    func getUser(jwt: String?) async throws -> User {
        let user = try await supabase.auth.user(jwt: jwt)
        return user.toDomain()
    }
}
