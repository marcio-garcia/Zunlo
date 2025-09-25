//
//  AuthStateManager.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import SwiftUI
import Combine
import LoggingKit

@MainActor
final class AuthStateManager: ObservableObject {
    @Published private(set) var state: AuthState = .loading
    @Published var isAnonymous: Bool = false

    var user: User? {
        didSet {
            isAnonymous = user?.isAnonymous ?? true
        }
    }

    var authToken: AuthToken? {
        if case .authenticated(let token) = state { return token }
        return nil
    }

    func updateState(_ newState: AuthState) {
        state = newState
    }

    func setAuthenticated(_ authToken: AuthToken, user: User) {
        self.user = user
        state = .authenticated(authToken)
    }

    func setUnauthenticated() {
        user = nil
        state = .unauthenticated
    }

    func setLoading() {
        state = .loading
    }
}