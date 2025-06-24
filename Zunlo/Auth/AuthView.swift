//
//  AuthView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/23/25.
//

import SwiftUI

struct AuthView: View {
    @StateObject private var repository = AuthRepository(envConfig: EnvConfig.shared)
    @State var email = "marcio.ca.garcia@gmail.com"
    @State var password = ""

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

            if repository.isLoading {
                ProgressView()
            } else {
                HStack {
                    Button("Sign Up") {
                        Task { await repository.signUp(email: email, password: password) }
                    }
                    .buttonStyle(.bordered)
                    Button("Sign In") {
                        Task { await repository.signIn(email: email, password: password) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let error = repository.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }

            if let token = repository.auth?.accessToken, !token.isEmpty {
                Text("Logged in! 🎉")
                    .foregroundColor(.green)
                Text(token.prefix(12) + "…")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .padding()
    }
}
