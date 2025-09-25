//
//  AuthRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import SwiftUI
import SwiftData
import Supabase
import GoogleSignIn

enum AuthServiceError: Error {
    case noIdToken
    case invalidCredentials
    case networkError(String)
    case unsupportedSignInMethod

    var localizedDescription: String {
        switch self {
        case .noIdToken:
            return "Failed to retrieve ID token from Google Sign-In"
        case .invalidCredentials:
            return "Invalid authentication credentials"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unsupportedSignInMethod:
            return "Unsupported sign-in method"
        }
    }
}

protocol AuthServicing {
    // Unified sign-in method
    func signIn(request: AuthSignInRequest) async throws -> AuthToken

    // Legacy methods for backward compatibility (will be deprecated)
    func signUp(email: String, password: String) async throws -> AuthSession
    func signIn(email: String, password: String) async throws -> AuthToken
    func signInAnonymously() async throws -> AuthToken
    func signInWithOTP(email: String, redirectTo: URL?) async throws
    func signInWithGoogle(viewController: UIViewController) async throws -> AuthToken

    // Session and token management
    func refreshToken(_ refreshToken: String) async throws -> AuthToken
    func session(from url: URL) async throws -> AuthSession
    func session() async throws -> AuthSession
    func validateToken(_ token: AuthToken) -> Bool
    func user(by jwt: String?) async throws -> User
    func signOut() async throws
    func updateUser(email: String) async throws
    func getOTPType(from typeString: String) -> EmailOTPType
    func verifyOTP(tokenHash: String, type: EmailOTPType) async throws -> AuthSession
    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws -> AuthSession
}

class AuthService: AuthServicing {
    
    private let supabaseProvider: AuthProvider
    private let googleProvider: GoogleAuthProvider

    init(supabase: SupabaseClient) {
        self.supabaseProvider = SupabaseAuthProvider(supabase: supabase)
        self.googleProvider = GoogleAuthProvider(supabase: supabase)
    }

    // MARK: - Unified Sign-In Method

    func signIn(request: AuthSignInRequest) async throws -> AuthToken {
        switch request.method {
        case .emailPassword(let email, let password):
            let session = try await supabaseProvider.signIn(email: email, password: password)
            return session.toDomain()

        case .magicLink(let email):
            try await supabaseProvider.signInWithOTP(email: email, redirectTo: request.redirectTo)
            throw AuthServiceError.unsupportedSignInMethod // Magic link doesn't return token immediately

        case .google(let viewController):
            let session = try await googleProvider.signInWithGoogle(viewController: viewController)
            return session.toDomain()

        case .anonymous:
            let session = try await supabaseProvider.signInAnonymously()
            return session.toDomain()
        }
    }

    // MARK: - Legacy Methods (Backward Compatibility)

    func signUp(email: String, password: String) async throws -> AuthSession {
        let authResponse = try await supabaseProvider.signUp(email: email, password: password)
        return authResponse.toDomain()
    }

    func signIn(email: String, password: String) async throws -> AuthToken {
        let session = try await supabaseProvider.signIn(email: email, password: password)
        return session.toDomain()
    }

    func signInAnonymously() async throws -> AuthToken {
        let session = try await supabaseProvider.signInAnonymously()
        return session.toDomain()
    }

    func signInWithOTP(email: String, redirectTo: URL?) async throws {
        try await supabaseProvider.signInWithOTP(email: email, redirectTo: redirectTo)
    }

    func signInWithGoogle(viewController: UIViewController) async throws -> AuthToken {
        let session = try await googleProvider.signInWithGoogle(viewController: viewController)
        return session.toDomain()
    }

    // MARK: - Session and Token Management

    func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        let session = try await supabaseProvider.refreshToken(refreshToken)
        return session.toDomain()
    }

    func validateToken(_ token: AuthToken) -> Bool {
        return !token.accessToken.isEmpty && token.expiresAt > Date()
    }

    func session(from url: URL) async throws -> AuthSession {
        let session = try await supabaseProvider.session(from: url)
        return AuthSession(token: session.toDomain(), user: session.user.toDomain())
    }

    func session() async throws -> AuthSession {
        let session = try await supabaseProvider.session()
        return AuthSession(token: session.toDomain(), user: session.user.toDomain())
    }

    func user(by jwt: String?) async throws -> User {
        let user = try await supabaseProvider.user(by: jwt)
        return user.toDomain()
    }

    func signOut() async throws {
        try await supabaseProvider.signOut()
        googleProvider.signOut()
    }

    func updateUser(email: String) async throws {
        try await supabaseProvider.updateUser(email: email)
    }

    func getOTPType(from typeString: String) -> EmailOTPType {
        return supabaseProvider.getOTPType(from: typeString)
    }

    func verifyOTP(tokenHash: String, type: EmailOTPType) async throws -> AuthSession {
        let authResponse = try await supabaseProvider.verifyOTP(tokenHash: tokenHash, type: type)
        return authResponse.toDomain()
    }

    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws -> AuthSession {
        let authResponse = try await supabaseProvider.verifyOTP(email: email, token: token, type: type)
        return authResponse.toDomain()
    }
}
