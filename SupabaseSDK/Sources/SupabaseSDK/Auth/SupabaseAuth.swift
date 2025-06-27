//
//  SupabaseAuth.swift
//  SupabaseSDK
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation

public class SupabaseAuth: @unchecked Sendable {
    private let config: SupabaseConfig
    
    public init(config: SupabaseConfig) {
        self.config = config
    }
    
    public func signUp(email: String, password: String) async throws -> SBAuth {
        let url = config.baseURL.appending(path: "auth/v1/signup")
        do {
            return try await authenticate(url: url, email: email, password: password)
        } catch {
            throw error
        }
    }

    public func signIn(email: String, password: String) async throws -> SBAuth {
        let url = config.baseURL.appending(path: "auth/v1/token")
        do {
            return try await authenticate(url: url, email: email, password: password)
        } catch {
            throw error
        }
    }

    private func authenticate(url: URL, email: String, password: String) async throws -> SBAuth {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "password")
        ]

        guard let url = components.url else {
            throw SBAuthError.invalidRequest
        }

        var request = URLRequest(url: url)
        
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        let payload = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw SBAuthError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                let sbAuthErrorMsg = try JSONDecoder().decode(SBAuthErrorMsg.self, from: data)
                throw SBAuthError.authError(sbAuthErrorMsg)
            }
            
            let sbAuth = try JSONDecoder().decode(SBAuth.self, from: data)
            return sbAuth
        } catch {
            if let err = error as? DecodingError {
                debugPrint("Decoding error: \(err.errorDescription ?? "")")
            }
            throw error
        }
    }
}
