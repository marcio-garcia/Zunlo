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
                    .themedTitle()
                    .multilineTextAlignment(.center)
                
                
                Text("Enter your email and we’ll send you a magic link to upgrade your account. No password needed.")
                    .themedHeadline()
                    .multilineTextAlignment(.center)
                
                TextField("Your email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .themedHeadline()
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .themedCallout()
                        .foregroundColor(.red)
                }
                
                if let successMessage = successMessage {
                    Text(successMessage)
                        .themedBody()
                        .foregroundColor(.green)
                }
                
                Button {
                    Task { await upgrade() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("Send Magic Link")
                            .cornerRadius(10)
                    }
                }
                .themedPrimaryButton()
                .disabled(isSending || email.isEmpty)
                
                Spacer()
            }
            .padding()
            .defaultBackground()
        }
    }
    
    private func upgrade() async {
        guard !email.isEmpty else { return }
        
        isSending = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await authManager.updateUser(email: email)
            successMessage = "Check your inbox to complete the upgrade."
        } catch {
            errorMessage = "Failed to send magic link: \(error.localizedDescription)"
        }
        
        isSending = false
    }
}
