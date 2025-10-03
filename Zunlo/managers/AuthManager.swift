//
//  AuthManager.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import UIKit
import Combine
import RealmSwift
import LoggingKit

enum AuthState: Equatable {
    case loading
    case authenticated(AuthToken)
    case unauthenticated
}

protocol TokenStorage {
    func save(authToken: AuthToken) throws
    func loadToken() throws -> AuthToken?
    func clear() throws
}

protocol UserStorage {
    func save(user: User) throws
    func loadUser() throws -> User?
    func clear() throws
}

enum AuthProvidingError: Error {
    case unauthorized
    case unableToSignUp(String)
    case confirmEmail(String)
    case noPresentingViewController
}

@MainActor
public protocol AuthProviding {
    var userId: UUID? { get }
    var accessToken: String? { get }
    func refreshSession(refreshToken: String?) async throws -> AuthToken?
    func isAuthorized() async throws -> Bool
}

@MainActor
final class AuthManager: ObservableObject, AuthProviding {
    @Published private(set) var state: AuthState = .loading
    @Published var isAnonymous: Bool = false

    private let businessLogic: AuthBusinessLogic
    private let stateManager = AuthStateManager()

    var user: User? { stateManager.user }
    var authToken: AuthToken? { stateManager.authToken }

    public var userId: UUID? {
        return user?.id
    }

    public var accessToken: String? {
        return authToken?.accessToken
    }
    
    init(
        authService: AuthServicing,
        tokenStorage: TokenStorage = AuthTokenStorage(),
        userStorage: UserStorage = AuthUserStorage()
    ) {
        self.businessLogic = AuthBusinessLogic(
            authService: authService,
            tokenStorage: tokenStorage,
            userStorage: userStorage
        )

        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .accessUnauthorized,
            object: nil,
            queue: .main
        ) { _ in
            Task(priority: .userInitiated) {
                await self.unauthenticated()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .authDeepLink,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task(priority: .userInitiated) { await self?.handleNotification(notification) }
        }
    }
    
    public func bootstrap(hasCompletedOnboarding: Bool) async {
        stateManager.setLoading()

        do {
            if let (authToken, user) = try await businessLogic.bootstrap(hasCompletedOnboarding: hasCompletedOnboarding) {
                updateStateFromManager(authToken: authToken, user: user)
            } else {
                setUnauthenticated()
            }
        } catch {
            log("Bootstrap failed: \(error.localizedDescription)", level: .error, category: "Auth")
            setUnauthenticated()
        }
    }
    
    public func isAuthorized() async throws -> Bool {
        do {
            return try await businessLogic.isAuthorized()
        } catch {
            await unauthenticated()
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let (authToken, user) = try await businessLogic.signIn(email: email, password: password)
        updateStateFromManager(authToken: authToken, user: user)
    }

    func signUp(email: String, password: String) async throws {
        if let (authToken, user) = try await businessLogic.signUp(email: email, password: password) {
            updateStateFromManager(authToken: authToken, user: user)
        }
    }

    func signInAnonymously() async throws {
        let (authToken, user) = try await businessLogic.signInAnonymously()
        updateStateFromManager(authToken: authToken, user: user)
    }

    func signInWithOTP(email: String) async throws {
        try await businessLogic.signInWithOTP(email: email)
    }

    func createSession(with url: URL) async throws {
        let authSession = try await businessLogic.createSession(with: url)
        guard let token = authSession.token else {
            throw AuthProvidingError.unauthorized
        }
        updateStateFromManager(authToken: token, user: authSession.user)
    }

    func signInWithGoogle(viewController: UIViewController) async throws {
        let (authToken, user) = try await businessLogic.signInWithGoogle(viewController: viewController)
        updateStateFromManager(authToken: authToken, user: user)
    }
    
    func signOut(preserveLocalData: Bool = true) async throws {
        try await businessLogic.signOut(preserveLocalData: preserveLocalData)
        await unauthenticated()
    }
    
    @discardableResult
    public func refreshSession(refreshToken: String? = nil) async throws -> AuthToken? {
        return try await businessLogic.refreshSession(refreshToken: refreshToken)
    }
    
    public func updateUser(email: String) async throws {
        try await businessLogic.updateUser(email: email)
    }
    
    public func resetPassword(password: String) async throws {
        try await businessLogic.resetPassword(password: password)
    }
    
    private func unauthenticated() async {
        setUnauthenticated()
    }
    
    private func handleNotification(_ notification: Notification) {
        if let url = notification.object as? URL {
            Task(priority: .userInitiated) {
                do {
                    try await self.createSession(with: url)
                } catch {
                    log("Failed to create session from deep link: \(error.localizedDescription)", level: .error, category: "Auth")
                    await unauthenticated()
                }
            }
        }
    }

    private func verifyAuthToken(tokenHash: String, type: String) async throws {
        let (authToken, user) = try await businessLogic.verifyAuthToken(tokenHash: tokenHash, type: type)
        updateStateFromManager(authToken: authToken, user: user)
    }

    // MARK: - Private Helpers

    private func updateStateFromManager(authToken: AuthToken, user: User) {
        stateManager.setAuthenticated(authToken, user: user)
        state = .authenticated(authToken)
        isAnonymous = user.isAnonymous
    }

    private func setUnauthenticated() {
        stateManager.setUnauthenticated()
        state = .unauthenticated
        isAnonymous = true
    }
}
