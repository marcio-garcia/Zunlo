//
//  AuthManager.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation
import Combine
import RealmSwift

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

public protocol AuthProviding {
    var userId: UUID? { get }
    var accessToken: String? { get }
    func refreshSession(refreshToken: String?) async throws -> AuthToken?
}

final class AuthManager: ObservableObject, AuthProviding {
    @Published private(set) var state: AuthState = .loading
    @Published var isAnonymous: Bool = false
    
    private var authService: AuthServicing
    private let tokenStorage: TokenStorage
    private let userStorage: UserStorage
    
    private var emailForMagicLink: String?
    
    var user: User?
    var authToken: AuthToken? {
        if case .authenticated(let token) = state { return token }
        return nil
    }
    
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
        self.authService = authService
        self.tokenStorage = tokenStorage
        self.userStorage = userStorage
        
        NotificationCenter.default.addObserver(forName: .accessUnauthorized,
                                               object: nil,
                                               queue: .main) { _ in
            Task {
                await self.unauthenticated()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .authDeepLink,
                                               object: nil,
                                               queue: .main) { [weak self] notification in
            self?.handleNotification(notification)
        }
    }
    
    public func bootstrap(hasCompletedOnboarding: Bool) async {
        do {
            guard let token = try tokenStorage.loadToken() else {
                return try await handleNoToken(hasCompletedOnboarding: hasCompletedOnboarding)
            }
            
            if authService.validateToken(token) {
                try await authenticated(token)
                return
            }

            if let refreshToken = token.refreshToken {
                try await refreshSession(refreshToken: refreshToken)
                return
            }

            await unauthenticated()
        } catch {
            await unauthenticated()
        }
    }

    private func handleNoToken(hasCompletedOnboarding: Bool) async throws {
        if hasCompletedOnboarding {
            await unauthenticated()
        } else {
            try await signInAnonymously()
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let auth = try await authService.signIn(email: email, password: password)
        try await authenticated(auth)
    }
    
    func signUp(email: String, password: String) async throws {
        let auth = try await authService.signUp(email: email, password: password)
        guard let authToken = auth.token else {
            await unauthenticated()
            return
        }
        try await authenticated(authToken)
    }
    
    func signInAnonymously() async throws {
        let authToken = try await authService.signInAnonymously()
        try await authenticated(authToken)
    }
    
    func signInWithOTP(email: String) async throws {
        do {
            emailForMagicLink = email
            try await authService.signInWithOTP(
                email: email,
                redirectTo: URL(string: "zunloapp://supabase/magiclink")
            )
        } catch {
            emailForMagicLink = nil
            throw error
        }
    }
    
    func signInWithMagicLink(url: URL) async throws {
        let (authToken, _) = try await authService.session(from: url)
        try await authenticated(authToken)
    }
        
    func signOut(preserveLocalData: Bool = true) async throws {
        do {
            // Revoke token with Supabase
            try await authService.signOut()
            
            // Clear session tokens
            try tokenStorage.clear()
            
            // Wipe local database
            if !preserveLocalData {
                try await Task.detached(priority: .background) {
                    let realm = try Realm()
                    try realm.write {
                        realm.deleteAll()
                    }
                }.value
            }
            
            await unauthenticated()
        } catch {
            print(error)
            await unauthenticated()
        }
    }
    
    @discardableResult
    public func refreshSession(refreshToken: String? = nil) async throws -> AuthToken? {
        var token = ""
        
        if let refreshToken {
            token = refreshToken
        } else if let refrtoken = authToken?.refreshToken {
            token = refrtoken
        } else {
            return nil
        }
        
        let newAuth = try await authService.refreshToken(token)
        if authService.validateToken(newAuth) {
            try await authenticated(newAuth)
            return newAuth
        }
        return nil
    }
    
    public func updateUser(email: String) async throws {
        try await authService.updateUser(email: email)
    }
    
    private func updateState(_ state: AuthState) async {
        await MainActor.run {
            self.state = state
            self.isAnonymous = user?.isAnonymous ?? true
        }
    }
    
    private func authenticated(_ authToken: AuthToken) async throws {
        try tokenStorage.save(authToken: authToken)
        let user = try await authService.user(by: authToken.accessToken)
        self.user = user
        try userStorage.save(user: user)
        await updateState(.authenticated(authToken))
    }
    
    private func unauthenticated() async {
        try? tokenStorage.clear()
        try? await authService.signOut()
        await updateState(.unauthenticated)
    }
    
    private func handleNotification(_ notification: Notification) {
        if let url = notification.object as? URL {
            Task {
                do {
                    try await self.signInWithMagicLink(url: url)
                } catch {
                    await unauthenticated()
                }
            }
        }
    }
    
    private func verifyAuthToken(tokenHash: String, type: String) async throws {
        let otpType = authService.getOTPType(from: type)
        let auth = try await authService.verifyOTP(
            tokenHash: tokenHash,
            type: otpType
        )
        
        guard let authToken = auth.token else {
            await unauthenticated()
            return
        }
        try await authenticated(authToken)
    }
}
