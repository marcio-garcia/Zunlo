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
                    RoundedSection(title: "Account") {
                        HStack {
                            if authManager.isAnonymous {
                                NavigationLink("Create Account to Save My Tasks") {
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
                        Button("Log Out") {
                            viewModel.confirmLogout()
                        }
                        if viewModel.isLoggingOut {
                            ProgressView()
                        }
                        LogoutPromptDialog(viewModel: viewModel)
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
            .errorAlert(viewModel.errorHandler)
        }
    }
}
