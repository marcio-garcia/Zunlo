//
//  SupabaseAuth.swift
//  SupabaseSDK
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation

public class SupabaseAuth {
    private let config: SupabaseConfig
    private let httpService: NetworkService
    
    public init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.httpService = NetworkService(config: config, session: session)
    }
    
    public func signUp(email: String, password: String) async throws -> SBAuth {
        return try await httpService.performRequest(
            path: "auth/v1/signup",
            method: .post,
            bodyObject: ["email": email, "password": password],
            query: ["grant_type": "password"]
        )
    }

    public func signIn(email: String, password: String) async throws -> SBAuth {
        return try await httpService.performRequest(
            path: "auth/v1/token",
            method: .post,
            bodyObject: ["email": email, "password": password],
            query: ["grant_type": "password"]
        )
    }
    
    public func refreshSession(refreshToken: String) async throws -> SBAuth {
        return try await httpService.performRequest(
            path: "auth/v1/token",
            method: .post,
            bodyObject: ["refresh_token": refreshToken],
            query: ["grant_type": "refresh_token"]
        )
    }
    
//    private func authenticate(request: URLRequest) async throws -> SBAuth {
//        do {
//            let (data, response) = try await URLSession.shared.data(for: request)
//            guard let http = response as? HTTPURLResponse else {
//                throw SBAuthError.invalidResponse
//            }
//            guard (200..<300).contains(http.statusCode) else {
//                let sbAuthErrorMsg = try JSONDecoder().decode(SBAuthErrorMsg.self, from: data)
//                throw SBAuthError.authError(sbAuthErrorMsg)
//            }
//            
//            let sbAuth = try JSONDecoder().decode(SBAuth.self, from: data)
//            return sbAuth
//        } catch {
//            if let err = error as? DecodingError {
//                debugPrint("Decoding error: \(err.errorDescription ?? "")")
//            }
//            throw error
//        }
//    }
}
