//
//  RootView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    var appState: AppState
    
    var body: some View {
        Group {
            switch authManager.state {
            case .loading:
                ProgressView("Loading...")
            case .unauthenticated:
                AuthView()
            case .authenticated(_):
                switch locationManager.status {
                case .notDetermined:
                    OnboardingLocationView {
                        locationManager.requestPermission()
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
        .animation(.easeInOut, value: authManager.state)
        .transition(.opacity)
        .task {
            await authManager.bootstrap()
            locationManager.checkStatus()
        }
    }
}
