//
//  AuthViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/23/25.
//

import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = "marcio.ca.garcia@gmail.com"
    @Published var password = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var isLoggedIn = false
    @Published var accessToken: String?

    let supabaseURL = EnvConfig.shared.apiBaseUrl
    let anonKey = EnvConfig.shared.apiKey

    func signUp() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        guard let url = URL(string: "\(supabaseURL)/auth/v1/signup") else { return }
        await authenticate(url: url)
    }

    func signIn() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password") else { return }
        await authenticate(url: url)
    }

    private func authenticate(url: URL) async {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        let payload = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            guard (200..<300).contains(http.statusCode) else {
                if let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errMsg = msg["msg"] as? String ?? msg["error_description"] as? String ?? msg["error"] as? String {
                    error = errMsg
                } else {
                    error = "Unknown error (\(http.statusCode))"
                }
                return
            }
            // Parse access token (works for both sign up and sign in)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                self.accessToken = token
                self.isLoggedIn = true
            } else {
                error = "Missing access token. Please check your email for verification."
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
