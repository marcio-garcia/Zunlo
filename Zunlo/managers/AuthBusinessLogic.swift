//
//  AuthBusinessLogic.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import UIKit
import RealmSwift
import LoggingKit

final class AuthBusinessLogic {
    private let authService: AuthServicing
    private let tokenStorage: TokenStorage
    private let userStorage: UserStorage

    init(
        authService: AuthServicing,
        tokenStorage: TokenStorage = AuthTokenStorage(),
        userStorage: UserStorage = AuthUserStorage()
    ) {
        self.authService = authService
        self.tokenStorage = tokenStorage
        self.userStorage = userStorage
    }

    // MARK: - Authentication Operations

    func signIn(email: String, password: String) async throws -> (AuthToken, User) {
        let authToken = try await authService.signIn(email: email, password: password)
        return try await processAuthentication(authToken)
    }

    func signUp(email: String, password: String) async throws -> (AuthToken, User)? {
        let auth = try await authService.signUp(email: email, password: password)
        guard let authToken = auth.token else {
            throw AuthProvidingError.confirmEmail("Please check your email for a confirmation link")
        }
        return try await processAuthentication(authToken)
    }

    func signInAnonymously() async throws -> (AuthToken, User) {
        let authToken = try await authService.signInAnonymously()
        return try await processAuthentication(authToken)
    }

    func signInWithOTP(email: String) async throws {
        try await authService.signInWithOTP(
            email: email,
            redirectTo: URL(string: "zunloapp://supabase/magiclink")
        )
    }

    func signInWithGoogle(viewController: UIViewController) async throws -> (AuthToken, User) {
        let authToken = try await authService.signInWithGoogle(viewController: viewController)
        return try await processAuthentication(authToken)
    }

    func createSession(with url: URL) async throws -> AuthSession {
        let authSession = try await authService.session(from: url)
        guard let token = authSession.token else {
            throw AuthProvidingError.unauthorized
        }
        try await saveAuthentication(authToken: token, user: authSession.user)
        return authSession
    }

    func refreshSession(refreshToken: String? = nil) async throws -> AuthToken? {
        var token = ""

        if let refreshToken {
            token = refreshToken
        } else if let existingToken = try tokenStorage.loadToken()?.refreshToken {
            token = existingToken
        } else {
            return nil
        }

        let newAuth = try await authService.refreshToken(token)
        if authService.validateToken(newAuth) {
            let user = try await authService.user(by: newAuth.accessToken)
            try await saveAuthentication(authToken: newAuth, user: user)
            return newAuth
        }
        return nil
    }

    func updateUser(email: String) async throws {
        try await authService.updateUser(email: email)
    }

    func signOut(preserveLocalData: Bool = true) async throws {
        do {
            // Revoke token with service
            try await authService.signOut()

            // Clear session tokens
            try tokenStorage.clear()

            // Wipe local database if requested
            if !preserveLocalData {
                try await clearLocalDatabase()
            }
        } catch {
            log("Failed to sign out: \\(error.localizedDescription)", level: .error, category: "Auth")
            throw error
        }
    }

    // MARK: - Session Management

    func bootstrap(hasCompletedOnboarding: Bool) async throws -> (AuthToken, User)? {
        guard let token = try tokenStorage.loadToken() else {
            if hasCompletedOnboarding {
                return nil // Will set unauthenticated
            } else {
                return try await signInAnonymously()
            }
        }

        if authService.validateToken(token) {
            let user = try await authService.user(by: token.accessToken)
            return (token, user)
        }

        if let refreshToken = token.refreshToken,
           let newToken = try await refreshSession(refreshToken: refreshToken) {
            let user = try await authService.user(by: newToken.accessToken)
            return (newToken, user)
        }

        return nil // Will set unauthenticated
    }

    func isAuthorized() async throws -> Bool {
        if let token = try tokenStorage.loadToken(), authService.validateToken(token) {
            return true
        }
        log("Not authorized", level: .info, category: "Auth")
        throw AuthProvidingError.unauthorized
    }

    func verifyAuthToken(tokenHash: String, type: String) async throws -> (AuthToken, User) {
        let otpType = authService.getOTPType(from: type)
        let auth = try await authService.verifyOTP(tokenHash: tokenHash, type: otpType)

        guard let authToken = auth.token else {
            throw AuthProvidingError.unauthorized
        }

        return try await processAuthentication(authToken)
    }
    
    func resetPassword(password: String) async throws {
        if try await isAuthorized() {
            try await authService.resetPassword(password: password)
        }
    }

    // MARK: - Private Helpers

    private func processAuthentication(_ authToken: AuthToken) async throws -> (AuthToken, User) {
        let user = try await authService.user(by: authToken.accessToken)
        try await saveAuthentication(authToken: authToken, user: user)
        return (authToken, user)
    }

    private func saveAuthentication(authToken: AuthToken, user: User) async throws {
        try tokenStorage.save(authToken: authToken)
        try userStorage.save(user: user)
    }

    private func clearLocalDatabase() async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            try realm.write {
                realm.deleteAll()
            }
        }.value
    }
}
