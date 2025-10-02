//
//  SettingsView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var upgradeFlowManager: UpgradeFlowManager
    @StateObject private var viewModel: LogoutViewModel
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        self._viewModel = StateObject(wrappedValue: LogoutViewModel(authManager: authManager))
    }

    var authManager: AuthManager
    
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
                            if authManager.isAnonymous {
                                NavigationLink("Create account to save data") {
                                    UpgradeAccountView(authManager: authManager)
                                }
                                .themedBody()
                            } else {
                                Text("You're signed in")
                                    .themedBody()
                            }
                            Spacer()
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Button(viewModel.isAnonymousUser ? "Sign in if you have an account" : "Log out") {
                            viewModel.confirmLogout()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 30)
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
                viewModel.isAnonymousUser = authManager.user?.isAnonymous ?? true
                viewModel.onLogoutComplete = {
                    dismiss()
                }
            }
            .errorToast(viewModel.errorHandler)
            .confirmationDialog(
                "You're using a guest account. Logging out will delete your tasks unless you create an account",
                isPresented: $viewModel.showLogoutPrompt,
                titleVisibility: viewModel.isAnonymousUser ? Visibility.visible : Visibility.hidden
            ) {
                if viewModel.isAnonymousUser {
                    Button("Create account") {
                        viewModel.showLogoutPrompt = false
                        dismiss()
                        viewModel.upgradeInstead()
                    }
                    .themedSecondaryButton()
                }
                
                Button(viewModel.isAnonymousUser ? "Sign in if you have an account" : "Log out") {
                    Task {
                        await viewModel.performLogout(preserveLocalData: viewModel.isAnonymousUser)
                    }
                }
                .themedSecondaryButton()
                
                Button("Cancel", role: .cancel) {
                    viewModel.showLogoutPrompt = false
                }
                .themedSecondaryButton()
            }
        }
    }
}
