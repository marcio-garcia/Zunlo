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

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var state: AuthState = .loading

    private let tokenStorage: TokenStorage
    private let authService: AuthServicing
    
    var auth: Auth? {
        if case .authenticated(let auth) = state { return auth }
        return nil
    }
    
    init(tokenStorage: TokenStorage = KeychainTokenStorage(),
         authService: AuthServicing = AuthService(envConfig: EnvConfig.shared)) {
        self.tokenStorage = tokenStorage
        self.authService = authService
        Task { await self.bootstrap() }
    }

    private func bootstrap() async {
        do {
            if let auth = try tokenStorage.loadToken() {
                if authService.validateToken(auth.token) {
                    self.state = .authenticated(auth)
                } else if let refreshToken = auth.token.refreshToken {
                    do {
                        let auth = try await authService.refreshToken(refreshToken)
                        if authService.validateToken(auth.token) {
                            try tokenStorage.save(token: auth)
                            self.state = .authenticated(auth)
                        }
                        try? tokenStorage.clear()
                        self.state = .unauthenticated
                    } catch {
                        try? tokenStorage.clear()
                        self.state = .unauthenticated
                    }
                } else {
                    try? tokenStorage.clear()
                    self.state = .unauthenticated
                }
            } else {
                self.state = .unauthenticated
            }
        } catch {
            self.state = .unauthenticated
        }
    }
    
    private func handleAuth(auth: Auth) {
        do {
            try tokenStorage.save(token: auth)
            self.state = .authenticated(auth)
        } catch {
            self.state = .unauthenticated
        }
    }

    func signIn(email: String, password: String) async throws {
        let auth = try await authService.signIn(email: email, password: password)
        handleAuth(auth: auth)
    }
    
    func signUp(email: String, password: String) async throws {
        let auth = try await authService.signUp(email: email, password: password)
        handleAuth(auth: auth)
    }

    func logout() {
        try? tokenStorage.clear()
        self.state = .unauthenticated
    }
}
