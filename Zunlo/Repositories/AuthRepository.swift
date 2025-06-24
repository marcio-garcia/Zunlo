//
//  AuthRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import SwiftUI
import SwiftData
import SupabaseSDK

@MainActor
class AuthRepository: ObservableObject {
    
    @Published private(set) var auth: Auth?
    @Published private(set) var error: String?
    @Published var isLoading = false
    
    private var supabase: SupabaseSDK
    
    init(envConfig: EnvConfig) {
        let config = SupabaseConfig(anonKey: envConfig.apiKey, baseURL: URL(string: envConfig.apiBaseUrl)!)
        supabase = SupabaseSDK(config: config)
    }
    
    func signUp(email: String, password: String) async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        
        let result = await supabase.auth.signUp(email: email, password: password)
        switch result {
        case .success(let sbAuth):
            auth = sbAuth.toDomain()
        case .failure(let error):
            if let err = error as? SBAuthError {
                switch err {
                case .authError(let message):
                    self.error = message.msg
                default:
                    self.error = err.localizedDescription
                }
            }
        }
    }
    
    func signIn(email: String, password: String) async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        
        let result = await supabase.auth.signIn(email: email, password: password)
        switch result {
        case .success(let sbAuth):
            auth = sbAuth.toDomain()
        case .failure(let error):
            if let err = error as? SBAuthError {
                switch err {
                case .authError(let message):
                    self.error = message.msg
                default:
                    self.error = err.localizedDescription
                }
            } else if let err = error as? DecodingError {
                self.error = err.errorDescription
            }
        }
    }
}
