//
//  RootView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authCoordinator: AppAuthCoordinator

    var body: some View {
        Group {
            switch authCoordinator.state {
            case .loading:
                ProgressView("Loading...")
            case .authenticated:
                TimelineScrollView()
            case .unauthenticated:
                AuthView()
            }
        }
        .animation(.easeInOut, value: authCoordinator.state)
        .transition(.opacity)
    }
}
