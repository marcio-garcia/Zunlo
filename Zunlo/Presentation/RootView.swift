//
//  RootView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var upgradeFlowManager: UpgradeFlowManager
    @EnvironmentObject var upgradeReminderManager: UpgradeReminderManager
    
    var appState: AppState
    
    var body: some View {
        Group {
            if upgradeFlowManager.shouldShowUpgradeFlow {
                UpgradeAccountView(authManager: authManager)
            } else if !hasCompletedOnboarding {
                OnboardingView(appState: appState) {
                    hasCompletedOnboarding = true
                }
            } else {
                switch authManager.state {
                case .loading:
                    ProgressView("Loading...")
                case .unauthenticated:
                    AuthView()
                case .authenticated(_):
                    MainView(factory: DefaultViewFactory(appState: appState))
                        .environmentObject(upgradeFlowManager)
                }
            }
        }
        .animation(.easeInOut, value: authManager.state)
        .transition(.opacity)
        .task {
            await authManager.bootstrap()
            locationService.checkStatus()
            upgradeReminderManager.recordSessionIfNeeded()
        }
    }
}
