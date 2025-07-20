//
//  UpgradeAccountView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI

struct UpgradeAccountView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var isSending = false
    @State private var successMessage: String?
    @State private var errorMessage: String?

    var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Save your tasks permanently")
                    .font(.headline)

                Text("Enter your email and we’ll send you a magic link to upgrade your account. No password needed.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)

                TextField("Your email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                if let successMessage = successMessage {
                    Text(successMessage)
                        .foregroundColor(.green)
                }

                Button {
                    Task { await upgrade() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("Send Magic Link")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(isSending || email.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Upgrade Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func upgrade() async {
        guard !email.isEmpty else { return }

        isSending = true
        errorMessage = nil
        successMessage = nil

        do {
            try await authManager.linkIdentityWithMagicLink(email: email)
            successMessage = "Check your inbox to complete the upgrade."
        } catch {
            errorMessage = "Failed to send magic link: \(error.localizedDescription)"
        }

        isSending = false
    }
}
