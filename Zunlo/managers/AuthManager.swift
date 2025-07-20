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

protocol AuthSession {
    var authToken: AuthToken? { get }
    var user: User? { get }
}

final class AuthManager: AuthSession, ObservableObject {
    @Published private(set) var state: AuthState = .loading
    
    private let tokenStorage: TokenStorage
    private var authService: AuthServicing
    
    var user: User?
    
    var authToken: AuthToken? {
        if case .authenticated(let token) = state { return token }
        return nil
    }
    
    init(tokenStorage: TokenStorage = KeychainTokenStorage(),
         authService: AuthServicing = AuthService(envConfig: EnvConfig.shared)) {
        self.tokenStorage = tokenStorage
        self.authService = authService
        
        NotificationCenter.default.addObserver(forName: .accessUnauthorized,
                                               object: nil,
                                               queue: nil) { _ in
            Task {
                await self.unauthenticated()
            }
        }
    }

    public func bootstrap() async {
        do {
            if let authToken = try tokenStorage.loadToken(), authService.validateToken(authToken) {
                try await authenticated(authToken)
                return
            }

            if let authToken = try tokenStorage.loadToken(), let refreshToken = authToken.refreshToken {
                do {
                    let newAuth = try await authService.refreshToken(refreshToken)
                    if authService.validateToken(newAuth) {
                        try await authenticated(newAuth)
                        return
                    }
                } catch {
                    // refresh failed, fall back to anon
                }
            }

            // fallback to anonymous
            let authToken = try await authService.signInAnonymously()
            try await authenticated(authToken)

        } catch {
            await unauthenticated()
        }
    }

//    public func bootstrap() async {
//        do {
//            guard let auth = try tokenStorage.loadToken() else {
//                await unauthenticated()
//                return
//            }
//
//            if authService.validateToken(auth.token) {
//                await authenticated(auth)
//                return
//            }
//
//            guard let refreshToken = auth.token.refreshToken else {
//                await unauthenticated()
//                return
//            }
//
//            do {
//                let newAuth = try await authService.refreshToken(refreshToken)
//                if authService.validateToken(newAuth.token) {
//                    await authenticated(newAuth)
//                    return
//                }
//                await unauthenticated()
//            } catch {
//                await unauthenticated()
//            }
//        } catch {
//            await unauthenticated()
//        }
//    }
    
    private func updateState(_ state: AuthState) async {
        await MainActor.run {
            self.state = state
        }
    }
    
    private func authenticated(_ authToken: AuthToken) async throws {
        try tokenStorage.save(authToken: authToken)
        await updateState(.authenticated(authToken))
    }
    
    private func unauthenticated() async {
        try? tokenStorage.clear()
        try? await authService.signOut()
        await updateState(.unauthenticated)
    }

    func signIn(email: String, password: String) async throws {
        let auth = try await authService.signIn(email: email, password: password)
        try await authenticated(auth)
    }
    
    func signUp(email: String, password: String) async throws {
        let auth = try await authService.signUp(email: email, password: password)
        self.user = auth.user
        guard let authToken = auth.token else {
            await unauthenticated()
            return
        }
        try await authenticated(authToken)
    }
    
    func signInAnonymously() async throws {
        let auth = try await authService.signInAnonymously()
        try await authenticated(auth)
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
            
            // Create a new anonymous session automatically (optional)
            let authToken = try await authService.signInAnonymously()
            try await authenticated(authToken)
        } catch {
            print(error)
            await unauthenticated()
        }
    }
    
    public func linkIdentityWithMagicLink(email: String) async throws {
        try await authService.linkIdentityWithMagicLink(email: email)
    }
}
