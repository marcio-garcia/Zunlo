//
//  OnboardingView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/16/25.
//

import SwiftUI

enum OnboardingStep {
    case welcome
    case location
    case notifications
    case done
}

struct OnboardingView: View {
    var appState: AppState
    let onFinish: () -> Void
    @State private var step: OnboardingStep = .welcome
    
    var body: some View {
        switch step {
        case .welcome:
            WelcomeView { step = .location }
        case .location:
            LocationPermissionView(locationService: appState.locationService!) { step = .notifications }
        case .notifications:
            NotificationPermissionView(pushService: appState.pushNotificationService!) { step = .done }
        case .done:
            ProgressView("Finishing setup…")
                .onAppear {
                    onFinish()
                }
        }
    }
}
