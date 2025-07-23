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

final class AuthManager: ObservableObject {
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
    
    init(
        authService: AuthServicing = AuthService(envConfig: EnvConfig.shared),
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
        
        NotificationCenter.default.addObserver(forName: .supabaseDeepLink,
                                               object: nil,
                                               queue: .main) { notif in
            if let url = notif.object as? URL {
                self.handleDeepLink(url: url)
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
            try await signInAnonymously()

        } catch {
            await unauthenticated()
        }
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
    
    public func updateUser(email: String) async throws {
        try await authService.updateUser(email: email)
    }
    
    func handleDeepLink(url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme,
            let host = components.host,
            let queryItems = components.queryItems
        else {
            return
        }
        
        var path = components.path.split(separator: "/")
        
        switch scheme {
        case "zunloapp":
            switch host {
            case "supabase":
                Task {
                    do {
                        switch path.removeFirst() {
                        case "magiclink":
                            let (authToken, _) = try await authService.session(from: url)
                            try await authenticated(authToken)
                        default:
                            guard let session = authToken else { return }
                            try await authenticated(session)
                        }
                    } catch {
                        print(error)
                        await unauthenticated()
                    }
                }
            default:
                break
            }
            
        default:
            break
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
