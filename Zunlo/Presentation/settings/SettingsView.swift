//
//  SettingsView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LogoutViewModel
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        self._viewModel = StateObject(wrappedValue: LogoutViewModel(authManager: authManager))
    }

    var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            VStack {
                Button("Log Out") {
                    viewModel.confirmLogout()
                }
                
                if viewModel.isLoggingOut {
                    ProgressView("Logging out...")
                }
                
#if DEBUG
                NavigationLink("Debug Menu") {
                    DebugMenuView()
                }
#endif
                LogoutPromptDialog(viewModel: viewModel)
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
