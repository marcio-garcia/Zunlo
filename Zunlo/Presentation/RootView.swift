//
//  RootView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var upgradeFlowManager: UpgradeFlowManager
    @EnvironmentObject var upgradeReminderManager: UpgradeReminderManager
    
    var appState: AppState
    
    var body: some View {
        Group {
            if !appSettings.hasCompletedOnboarding {
                OnboardingView(appState: appState) {
                    appSettings.hasCompletedOnboarding = true
                }
            } else {
                switch authManager.state {
                case .loading:
                    VStack {
                        ProgressView("Loading...")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .defaultBackground()
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
            await authManager.bootstrap(hasCompletedOnboarding: appSettings.hasCompletedOnboarding)
            locationService.checkStatus()
            upgradeReminderManager.recordSessionIfNeeded()
        }
//        .sheet(isPresented: $upgradeFlowManager.shouldShowUpgradeFlow) {
//            UpgradeAccountView(authManager: authManager)
//        }
    }
}
