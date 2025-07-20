//
//  AuthRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import SwiftUI
import SwiftData
import SupabaseSDK

protocol AuthServicing {
    var authToken: String? { get set }
    func signIn(email: String, password: String) async throws -> Auth
    func signUp(email: String, password: String) async throws -> Auth
    func refreshToken(_ refreshToken: String) async throws -> Auth
    func validateToken(_ token: AuthToken) -> Bool
    func signOut() async throws
    func linkIdentityWithMagicLink(email: String) async throws
}

class AuthService: AuthServicing {
    
    private var supabase: SupabaseSDK
    
    var authToken: String? {
        didSet {
            supabase.auth.authToken = authToken
        }
    }
    
    init(envConfig: EnvConfig) {
        let config = SupabaseConfig(anonKey: envConfig.apiKey,
                                    baseURL: URL(string: envConfig.apiBaseUrl)!,
                                    functionsBaseURL: URL(string: envConfig.apiFunctionsBaseUrl))
        supabase = SupabaseSDK(config: config)
    }
    
    func signUp(email: String, password: String) async throws -> Auth {
        do {
            let sbAuth = try await supabase.auth.signUp(email: email, password: password)
            return sbAuth.toDomain()
        } catch {
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws -> Auth {
        do {
            let sbAuth = try await supabase.auth.signIn(email: email, password: password)
            return sbAuth.toDomain()
        } catch {
            throw error
        }
    }
    
    func refreshToken(_ refreshToken: String) async throws -> Auth {
        do {
            let sbAuth = try await supabase.auth.refreshSession(refreshToken: refreshToken)
            return sbAuth.toDomain()
        } catch {
            throw error
        }
    }
    
    func validateToken(_ token: AuthToken) -> Bool {
        return !token.accessToken.isEmpty && token.expiresAt > Date()
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    func linkIdentityWithMagicLink(email: String) async throws {
        try await supabase.auth.linkIdentityWithMagicLink(email: email)
    }
}
