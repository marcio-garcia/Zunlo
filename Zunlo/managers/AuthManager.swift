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
    case authenticated(Auth)
    case unauthenticated
}

protocol TokenStorage {
    func save(token: Auth) throws
    func loadToken() throws -> Auth?
    func clear() throws
}

protocol AuthSession {
    var auth: Auth? { get }
    var accessToken: String? { get }
}

final class AuthManager: AuthSession, ObservableObject {
    @Published private(set) var state: AuthState = .loading
    
    private let tokenStorage: TokenStorage
    private var authService: AuthServicing
    
    var auth: Auth? {
        if case .authenticated(let auth) = state { return auth }
        return nil
    }
    
    var accessToken: String? {
        auth?.token.accessToken
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
            guard let auth = try tokenStorage.loadToken() else {
                await unauthenticated()
                return
            }

            if authService.validateToken(auth.token) {
                await authenticated(auth)
                return
            }

            guard let refreshToken = auth.token.refreshToken else {
                await unauthenticated()
                return
            }

            do {
                let newAuth = try await authService.refreshToken(refreshToken)
                if authService.validateToken(newAuth.token) {
                    await authenticated(newAuth)
                    return
                }
                await unauthenticated()
            } catch {
                await unauthenticated()
            }
        } catch {
            await unauthenticated()
        }
    }
    
    private func updateState(_ state: AuthState) async {
        await MainActor.run {
            self.state = state
        }
    }
    
    private func authenticated(_ auth: Auth) async {
        do {
            try tokenStorage.save(token: auth)
            authService.authToken = auth.token.accessToken
            await updateState(.authenticated(auth))
        } catch {
            await unauthenticated()
        }
    }
    
    private func unauthenticated() async {
        try? tokenStorage.clear()
        authService.authToken = nil
        await updateState(.unauthenticated)
    }

    func signIn(email: String, password: String) async throws {
        let auth = try await authService.signIn(email: email, password: password)
        await authenticated(auth)
    }
    
    func signUp(email: String, password: String) async throws {
        let auth = try await authService.signUp(email: email, password: password)
        await authenticated(auth)
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
            
            // 3. Set app state to "unauthenticated"
            await updateState(.unauthenticated)
            
            // 4. Create a new anonymous session automatically (optional)
            //        let session = try? await supabaseAuth.signInAnonymously()
            //        sessionManager.set(session)
        } catch {
            print(error)
            try tokenStorage.clear()
        }
    }
    
    public func linkIdentityWithMagicLink(email: String) async throws {
        guard let accessToken else {
            return
        }
        try await authService.linkIdentityWithMagicLink(email: email)
    }
}
