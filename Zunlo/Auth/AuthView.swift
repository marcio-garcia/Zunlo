//
//  AuthView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/23/25.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Text("Supabase Auth Demo")
                    .themedTitle()
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
                    .themedBody()
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .themedBody()
                
                HStack {
                    Button("Sign Up") {
                        Task {
                            isLoading = true
                            defer { isLoading = false }
                            do {
                                try await authManager.signUp(email: email, password: password)
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                    .themedPrimaryButton()
                    .disabled(isLoading)
                    
                    Button("Sign In") {
                        Task {
                            do {
                                isLoading = true
                                defer { isLoading = false }
                                try await authManager.signIn(email: email, password: password)
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                    .themedSecondaryButton()
                    .disabled(isLoading)
                }
                
                Button("Sign in with Magic Link") {
                    Task {
                        do {
                            isLoading = true
                            defer { isLoading = false }
                            try await authManager.signInWithOTP(email: email)
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                .themedSecondaryButton()
                
                if let error = error {
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .themedCaption()
                        .foregroundColor(.red)
                }
                
                if isLoading {
                    ProgressView("Authenticating…")
                        .padding()
                        .themedBody()
                }
                
                Spacer()
            }
            .padding()
        }
        .defaultBackground()
    }
}
