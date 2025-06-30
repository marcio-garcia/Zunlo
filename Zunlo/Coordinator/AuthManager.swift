//
//  AuthManager.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Combine

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
    private let authService: AuthServicing
    
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
        Task { await self.bootstrap() }
    }

    private func bootstrap() async {
        do {
            guard let auth = try tokenStorage.loadToken() else {
                await unauthenticated()
                return
            }

            if authService.validateToken(auth.token) {
                await updateState(.authenticated(auth))
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
                }
            } catch {
                await unauthenticated()
            }
            await unauthenticated()
        } catch {
            await unauthenticated()
        }
    }
    
    @MainActor
    private func updateState(_ state: AuthState) {
        self.state = state
    }
    
    private func authenticated(_ auth: Auth) async {
        do {
            try tokenStorage.save(token: auth)
            await updateState(.authenticated(auth))
        } catch {
            await updateState(.unauthenticated)
        }
    }
    
    private func unauthenticated() async {
        try? tokenStorage.clear()
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

    @MainActor
    func logout() {
        try? tokenStorage.clear()
        updateState(.unauthenticated)
    }
}
