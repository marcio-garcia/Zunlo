//
//  LogoutPromptDialog.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI

struct LogoutPromptDialog: View {
    @ObservedObject var viewModel: LogoutViewModel

    var body: some View {
        if viewModel.showLogoutPrompt {
            VStack {
                Text(viewModel.isAnonymousUser
                     ? "You're using a guest account. Logging out will delete your tasks unless you save them."
                     : "Are you sure you want to log out?")
                    .font(.headline)
                    .padding()

                HStack {
                    Button("Cancel") {
                        viewModel.showLogoutPrompt = false
                    }
                    .padding()

                    if viewModel.isAnonymousUser {
                        Button("Save & Upgrade") {
                            viewModel.upgradeInstead()
                        }
                        .padding()
                    }

                    Button("Log Out") {
                        Task {
                            await viewModel.performLogout(preserveLocalData: viewModel.isAnonymousUser)
                        }
                    }
                    .foregroundColor(.red)
                    .padding()
                }
            }
            .frame(maxWidth: 300)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
}
