//
//  SettingsView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI
import GlowUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var upgradeFlowManager: UpgradeFlowManager
    @StateObject private var viewModel: SettingsViewModel
    @State var newPassword: String = ""
    
    init(authManager: AuthManager) {
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(authManager: authManager))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
#if DEBUG
                    RoundedSection {
                        HStack {
                            NavigationLink("Debug Menu") {
                                DebugMenuView()
                            }
                            .themedBody()
                            Spacer()
                        }
                    }
#endif
//                    RoundedSection(title: "Availability") {
//                        AvailabilitySettings()
//                    }
                    
                    RoundedSection(title: "Focus") {
                        FreeWindowSettings()
                    }
                    
                    RoundedSection(title: "Account") {
                        HStack {
                            if viewModel.isAnonymous {
                                NavigationLink("Create account to save data") {
                                    UpgradeAccountView(authManager: viewModel.authManager)
                                }
                                .themedBody()
                            } else {
                                Button("Change password") {
                                    viewModel.showChangePassword = true
                                }
                                .themedBody()
                            }
                            Spacer()
                        }
                        
                        HStack {
                            Button(viewModel.isAnonymous ? "Sign in if you have an account" : "Log out") {
                                viewModel.confirmLogout()
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding()
            }
            .defaultBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .themedSubtitle()
                }
            }
            .onAppear {
                viewModel.onLogoutComplete = {
                    dismiss()
                }
            }
            .confirmationDialog(
                "You're using a guest account. Logging out will delete your tasks unless you create an account",
                isPresented: $viewModel.showLogoutPrompt,
                titleVisibility: viewModel.isAnonymous ? Visibility.visible : Visibility.hidden
            ) {
                if viewModel.isAnonymous {
                    Button("Create account") {
                        viewModel.showLogoutPrompt = false
                        dismiss()
                        viewModel.upgradeInstead()
                    }
                    .themedSecondaryButton()
                }
                
                Button(viewModel.isAnonymous ? "Sign in if you have an account" : "Log out", role: .destructive) {
                    Task {
                        await viewModel.performLogout(preserveLocalData: viewModel.isAnonymous)
                    }
                }
                .themedSecondaryButton()
                
                Button("Cancel", role: .cancel) {
                    viewModel.showLogoutPrompt = false
                }
                .themedSecondaryButton()
            }
            .sheet(isPresented: $viewModel.showChangePassword) {
                VStack(spacing: 20) {
                    Text("Enter new password")
                        .themedHeadline()
                    
                    PrimarySecureField("", text: $newPassword)
                    
                    if let msg = viewModel.passwordErrorMessage {
                        Text(msg)
                            .appFont(.caption)
                            .foregroundColor(Color.red)
                    }
                    
                    Button("Reset") {
                        Task {
                            await viewModel.changePassword(password: newPassword)
                            newPassword = ""
                        }
                    }
                    .themedPrimaryButton()
                }
                .padding(20)
                .presentationDetents([.fraction(0.3)])
                .presentationDragIndicator(.visible)
            }
            .errorToast(viewModel.errorHandler)
        }
    }
}
