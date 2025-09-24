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

protocol AuthServicing {
    func signUp(email: String, password: String) async throws -> AuthSession
    func signIn(email: String, password: String) async throws -> AuthToken
    func signInAnonymously() async throws -> AuthToken
    func refreshToken(_ refreshToken: String) async throws -> AuthToken
    func session(from url: URL) async throws -> (AuthToken, User)
    func session() async throws -> (AuthToken, User)
    func validateToken(_ token: AuthToken) -> Bool
    func user(by jwt: String?) async throws -> User
    func signOut() async throws
    func signInWithOTP(email: String, redirectTo: URL?) async throws
    func signInWithGoogle(viewController: UIViewController) async throws -> AuthToken
    func updateUser(email: String) async throws
    func getOTPType(from typeString: String) -> EmailOTPType
    func verifyOTP(tokenHash: String, type: EmailOTPType) async throws -> AuthSession
    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws -> AuthSession
}

class AuthService: AuthServicing {
    
    private var supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
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
    
    func updateUser(email: String) async throws {
        try await supabase.auth.update(user: UserAttributes(email: email),
                                       redirectTo: URL(string: "zunloapp://auth-callback"))
    }
    
    func session(from url: URL) async throws -> (AuthToken, User) {
        let session = try await supabase.auth.session(from: url)
        return (session.toDomain(), session.user.toDomain())
    }
    
    func session() async throws -> (AuthToken, User) {
        let session = try await supabase.auth.session
        return (session.toDomain(), session.user.toDomain())
    }
    
    func user(by jwt: String?) async throws -> User {
        let user = try await supabase.auth.user(jwt: jwt)
        return user.toDomain()
    }
    
    func signInWithOTP(email: String, redirectTo: URL?) async throws {
        try await supabase.auth.signInWithOTP(email: email,
                                              redirectTo: redirectTo)
    }
    
    func verifyOTP(tokenHash: String, type: EmailOTPType) async throws -> AuthSession {
        let authResponse = try await supabase.auth.verifyOTP(tokenHash: tokenHash, type: type)
        return authResponse.toDomain()
    }
    
    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws -> AuthSession {
        let authResponse = try await supabase.auth.verifyOTP(
            email: email,
            token: token,
            type: type
        )
        return authResponse.toDomain()
    }
    
    @MainActor
    func signInWithGoogle(viewController: UIViewController) async throws -> AuthToken {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "zunlo", code: 99) // AuthError.noIdToken
        }
        
        let accessToken = result.user.accessToken.tokenString
        
        // Step 2: Sign in to Supabase with Google credentials
        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
        return session.toDomain()
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
}
