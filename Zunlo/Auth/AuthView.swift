//
//  AuthView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/23/25.
//

import SwiftUI

struct AuthView: View {
    //    @StateObject private var repository = AuthService(envConfig: EnvConfig.shared)
    //    @State var email = "marcio.ca.garcia@gmail.com"
    //    @State var password = ""
    
    @EnvironmentObject var authCoordinator: AppAuthCoordinator
    @State private var email = "marcio.ca.garcia@gmail.com"
    @State private var password = ""
    @State private var error: String?
    @State private var isLoading = false
    
    // To logout in any other view
    //    @EnvironmentObject var authCoordinator: AppAuthCoordinator
    //
    //    Button("Log out") {
    //        authCoordinator.logout()
    //    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Supabase Auth Demo")
                .font(.title).bold()
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Sign Up") {
                    Task {
                        isLoading = true
                                defer { isLoading = false }
                                do {
                                    try await authCoordinator.signUp(email: email, password: password)
                                } catch {
                                    self.error = error.localizedDescription
                                }
                    }
                    //                        Task { await repository.signUp(email: email, password: password) }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                Button("Sign In") {
                    Task {
                        do {
                            isLoading = true
                                    defer { isLoading = false }
                                    do {
                                        try await authCoordinator.signIn(email: email, password: password)
                                    } catch {
                                        self.error = error.localizedDescription
                                    }
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                    //                        Task { await repository.signIn(email: email, password: password) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            
            if isLoading {
                ProgressView("Authenticating…")
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}
