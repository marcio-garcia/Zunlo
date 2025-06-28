//
//  AuthManager.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Combine

enum AuthState: Equatable {
    case loading
    case authenticated(AuthToken)
    case unauthenticated
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var state: AuthState = .loading

    private let tokenStorage: TokenStorage
    private let authService: AuthServicing

    var currentToken: AuthToken? {
        if case .authenticated(let token) = state { return token }
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
            if let token = try tokenStorage.loadToken() {
                if authService.validateToken(token) {
                    self.state = .authenticated(token)
                } else if let refreshToken = token.refreshToken {
                    do {
                        let auth = try await authService.refreshToken(refreshToken)
                        if authService.validateToken(auth.token) {
                            try tokenStorage.save(token: auth.token)
                            self.state = .authenticated(auth.token)
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
    
    private func handleLogin(token: AuthToken) {
        do {
            try tokenStorage.save(token: token)
            self.state = .authenticated(token)
        } catch {
            self.state = .unauthenticated
        }
    }

    func signIn(email: String, password: String) async throws {
        let auth = try await authService.signIn(email: email, password: password)
        handleLogin(token: auth.token)
    }
    
    func signUp(email: String, password: String) async throws {
        let auth = try await authService.signUp(email: email, password: password)
        handleLogin(token: auth.token)
    }

    func logout() {
        try? tokenStorage.clear()
        self.state = .unauthenticated
    }
}
