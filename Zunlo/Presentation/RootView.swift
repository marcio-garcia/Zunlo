//
//  RootView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var locationManager = LocationManager()
    var eventRepository: EventRepository
    
    init(eventRepository: EventRepository) {
        self.eventRepository = eventRepository
    }
    
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
                    CalendarScheduleView(repository: eventRepository)
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
