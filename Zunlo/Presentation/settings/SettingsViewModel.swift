//
//  LogoutViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI
import RealmSwift

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var showLogoutPrompt = false
    @Published var isLoggingOut = false
    @Published var showChangePassword: Bool = false
    @Published var showPasswordMessage: Bool = false
    @Published var passwordErrorMessage: String?
    
    var resetPasswaordMessage: String = "Passord changed"

    let errorHandler = ErrorHandler()
    
    var authManager: AuthManager
    var onLogoutComplete: (() -> Void)?

    var isAnonymous: Bool {
        return authManager.isAnonymous
    }
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    func confirmLogout() {
        showLogoutPrompt = true
    }

    func performLogout(preserveLocalData: Bool = true) async {
        isLoggingOut = true

        do {
            try await authManager.signOut(preserveLocalData: preserveLocalData)
            isLoggingOut = false
            onLogoutComplete?()
        } catch {
            errorHandler.handle(error)
        }
    }

    func upgradeInstead() {
        // Trigger upgrade flow — e.g. show signup sheet
        NotificationCenter.default.post(name: .showUpgradeFlow, object: nil)
    }
    
    func changePassword(password: String) async {
        do {
            try await authManager.resetPassword(password: password)
            showChangePassword = false
            Task {
                try await Task.sleep(for: .seconds(0.5))
                errorHandler.message(resetPasswaordMessage)
            }
        } catch {
            passwordErrorMessage = error.localizedDescription
        }
    }
}
