//
//  RootView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    var appState: AppState
    
    var body: some View {
        Group {
            switch appState.authManager.state {
            case .loading:
                ProgressView("Loading...")
            case .unauthenticated:
                AuthView()
            case .authenticated(_):
                switch appState.locationManager.status {
                case .notDetermined:
                    OnboardingLocationView {
                        appState.locationManager.requestPermission()
                    }
                case .denied, .restricted:
                    LocationDeniedView()
                case .authorizedWhenInUse, .authorizedAlways:
                    MainView(factory: DefaultViewFactory(appState: appState))
                @unknown default:
                    ProgressView("Checking location permission...")
                }
            }
        }
        .animation(.easeInOut, value: appState.authManager.state)
        .transition(.opacity)
        .task {
            await appState.authManager.bootstrap()
            appState.locationManager.checkStatus()
        }
    }
}
