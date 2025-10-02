//
//  AuthView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/23/25.
//

import SwiftUI
import GlowUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var currentAction: String?
    @State private var showMagicLinkSent = false
    @FocusState private var focusedField: Field?
    let errorHandler = ErrorHandler()

    enum Field {
        case email
        case password
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func validateForm(requirePassword: Bool = true) -> Bool {
        errorHandler.clear()

        if email.isEmpty {
            errorHandler.handle(String(localized: "Please enter your email address"))
            return false
        }

        if !isValidEmail(email) {
            errorHandler.handle(String(localized: "Please enter a valid email address"))
            return false
        }

        if requirePassword && password.isEmpty {
            errorHandler.handle(String(localized: "Please enter your password"))
            return false
        }

        return true
    }

    private func signInAction() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard validateForm() else { return }
        Task {
            isLoading = true
            currentAction = "Signing in"
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorHandler.handle(error)
            }
            isLoading = false
            currentAction = nil
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Text("Zunlo")
                    .themedTitle()
                Spacer()
                PrimaryTextField("Email", text: $email)
                    .axis(.horizontal)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .themedBody()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
                    .accessibilityLabel("Email address")
                    .accessibilityHint("Enter your email address to sign in")
                    .onChange(of: email) { _, _ in
                        errorHandler.clear()
                    }

                PrimarySecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .themedBody()
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        signInAction()
                    }
                    .accessibilityLabel("Password")
                    .accessibilityHint("Enter your password")
                    .onChange(of: password) { _, _ in
                        errorHandler.clear()
                    }
                
                VStack(spacing: 20) {
                    Button("Sign in") {
                        signInAction()
                    }
                    .frame(minWidth: 230, minHeight: 38)
                    .background(Color.theme.accent)
                    .foregroundColor(.white)
                    .appFont(.button)
                    .cornerRadius(8)
                    .disabled(isLoading)
                    .accessibilityLabel("Sign in")
                    .accessibilityHint("Sign in with your email and password")
                    
                    Button("Sign in with Magic Link") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        guard validateForm(requirePassword: false) else { return }
                        Task {
                            isLoading = true
                            currentAction = "Sending magic link"
                            do {
                                try await authManager.signInWithOTP(email: email)
                                showMagicLinkSent = true
                            } catch {
                                errorHandler.handle(error)
                            }
                            isLoading = false
                            currentAction = nil
                        }
                    }
                    .frame(minWidth: 230, minHeight: 38)
                    .background(Color.theme.accent)
                    .foregroundColor(.white)
                    .appFont(.button)
                    .cornerRadius(8)
                    .disabled(isLoading)
                    .accessibilityLabel("Sign in with magic link")
                    .accessibilityHint("Send a magic link to your email address")

                    Button("Sign in with Google") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        Task {
                            isLoading = true
                            currentAction = "Signing in"
                            do {
                                guard let viewController = UIApplication.shared.rootViewController else {
                                    errorHandler.handle(String(localized: "Could not open the sign in screen"))
                                    return
                                }
                                try await authManager.signInWithGoogle(viewController: viewController)
                            } catch {
                                errorHandler.handle(error)
                            }
                            isLoading = false
                            currentAction = nil
                        }
                    }
                    .frame(minWidth: 230, minHeight: 38)
                    .background(Color.theme.accent)
                    .foregroundColor(.white)
                    .appFont(.button)
                    .cornerRadius(8)
                    .disabled(isLoading)
                    .accessibilityLabel("Sign in with Google")
                    .accessibilityHint("Sign in with your Google account")

                    
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.theme.accent.opacity(0.3))
                        Text("or")
                            .themedCaption()
                            .padding(.horizontal, 8)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.theme.accent.opacity(0.3))
                    }
                    .padding(.vertical, 10)
                    
                    Button("Create account") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        guard validateForm() else { return }
                        Task {
                            isLoading = true
                            currentAction = "Creating account"
                            do {
                                try await authManager.signUp(email: email, password: password)
                            } catch {
                                errorHandler.handle(error)
                            }
                            isLoading = false
                            currentAction = nil
                        }
                    }
                    .themedSecondaryButton()
                    .disabled(isLoading)
                    .accessibilityLabel("Create account")
                    .accessibilityHint("Create a new account with your email and password")
                }
                .padding(.vertical, 30)
                
                Spacer()
            }
            .padding()
            
            if isLoading {
                Color.theme.background.opacity(0.5)
                ProgressView(currentAction ?? "Loading…")
                    .padding()
                    .themedBody()
            }
        }
        .defaultBackground()
        .errorToast(errorHandler)
        .alert("Magic Link Sent", isPresented: $showMagicLinkSent) {
            Button("OK") { }
        } message: {
            Text("Please check your email for a confirmation link to sign in.")
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
