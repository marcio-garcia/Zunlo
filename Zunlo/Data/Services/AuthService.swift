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
    func signIn(email: String, password: String) async throws -> Auth
    func signUp(email: String, password: String) async throws -> Auth
    func refreshToken(_ refreshToken: String) async throws -> Auth
    func validateToken(_ token: AuthToken) -> Bool
}

class AuthService: AuthServicing {
    
    private var supabase: SupabaseSDK
    
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
}
