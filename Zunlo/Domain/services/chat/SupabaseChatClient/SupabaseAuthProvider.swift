//
//  SupabaseAuthProvider.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/5/25.
//

import Supabase

public protocol AuthProvider {
    func currentAccessToken() async throws -> String?
}

public struct SupabaseAuthProvider: AuthProvider {
    private let supabase: SupabaseClient
    public init(supabase: SupabaseClient) { self.supabase = supabase }
    public func currentAccessToken() async throws -> String? {
        if let session = try? await supabase.auth.session {
            return session.accessToken
        }
        print("[AI] WARNING: no auth session; chat-msg may 401/500")
        return nil
    }
}
