//
//  SupabaseAuthProvider.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation
import Supabase

protocol AuthProvider {
    func signUp(email: String, password: String) async throws -> AuthResponse
    func signIn(email: String, password: String) async throws -> Session
    func signInAnonymously() async throws -> Session
    func refreshToken(_ refreshToken: String) async throws -> Session
    func session(from url: URL) async throws -> Session
    func session() async throws -> Session
    func user(by jwt: String?) async throws -> Supabase.User
    func signOut() async throws
    func signInWithOTP(email: String, redirectTo: URL?) async throws
    func updateUser(email: String) async throws
    func getOTPType(from typeString: String) -> EmailOTPType
    func verifyOTP(tokenHash: String, type: EmailOTPType) async throws -> AuthResponse
    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws -> AuthResponse
}

final class SupabaseAuthProvider: AuthProvider {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func signUp(email: String, password: String) async throws -> AuthResponse {
        try await supabase.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signInAnonymously() async throws -> Session {
        try await supabase.auth.signInAnonymously()
    }

    func refreshToken(_ refreshToken: String) async throws -> Session {
        try await supabase.auth.refreshSession(refreshToken: refreshToken)
    }

    func session(from url: URL) async throws -> Session {
        try await supabase.auth.session(from: url)
    }

    func session() async throws -> Session {
        try await supabase.auth.session
    }

    func user(by jwt: String?) async throws -> Supabase.User {
        try await supabase.auth.user(jwt: jwt)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    func signInWithOTP(email: String, redirectTo: URL?) async throws {
        try await supabase.auth.signInWithOTP(email: email, redirectTo: redirectTo)
    }

    func updateUser(email: String) async throws {
        try await supabase.auth.update(
            user: UserAttributes(email: email),
            redirectTo: URL(string: "zunloapp://auth-callback")
        )
    }

    func getOTPType(from typeString: String) -> EmailOTPType {
        switch typeString {
        case "email_change":
            return .emailChange
        case "email":
            return .email
        case "signup":
            return .signup
        case "magiclink":
            return .magiclink
        default:
            return .email
        }
    }

    func verifyOTP(tokenHash: String, type: EmailOTPType) async throws -> AuthResponse {
        try await supabase.auth.verifyOTP(tokenHash: tokenHash, type: type)
    }

    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws -> AuthResponse {
        return try await supabase.auth.verifyOTP(
            email: email,
            token: token,
            type: type
        )
    }
}
