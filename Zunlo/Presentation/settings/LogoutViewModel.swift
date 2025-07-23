//
//  LogoutViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI
import RealmSwift

@MainActor
final class LogoutViewModel: ObservableObject {
    @Published var showLogoutPrompt = false
    @Published var isLoggingOut = false

    let errorHandler = ErrorHandler()
    
    var authManager: AuthManager
    var isAnonymousUser: Bool = true
    var onLogoutComplete: (() -> Void)?

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
}
