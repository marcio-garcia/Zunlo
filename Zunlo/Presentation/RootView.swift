//
//  RootView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    var eventRepository: EventRepository
    
    init(eventRepository: EventRepository) {
        self.eventRepository = eventRepository
    }
    
    var body: some View {
        Group {
            switch authManager.state {
            case .loading:
                ProgressView("Loading...")
            case .authenticated(_):
                CalendarScheduleView(repository: self.eventRepository)
            case .unauthenticated:
                AuthView()
            }
        }
        .animation(.easeInOut, value: authManager.state)
        .transition(.opacity)
        .task {
            await authManager.bootstrap()
        }
    }
}
