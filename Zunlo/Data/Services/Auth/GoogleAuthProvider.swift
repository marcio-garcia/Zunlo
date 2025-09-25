//
//  GoogleAuthProvider.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import UIKit
import GoogleSignIn
import Supabase

protocol GoogleAuthProviding {
    func signInWithGoogle(viewController: UIViewController) async throws -> Session
    func signOut()
}

final class GoogleAuthProvider: GoogleAuthProviding {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    @MainActor
    func signInWithGoogle(viewController: UIViewController) async throws -> Session {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthServiceError.noIdToken
        }

        let accessToken = result.user.accessToken.tokenString

        // Sign in to Supabase with Google credentials
        return try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}
