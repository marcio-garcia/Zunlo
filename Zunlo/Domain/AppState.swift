//
//  AppState.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SupabaseSDK

final class AppState {
    let authManager: AuthManager
    let eventRepository: EventRepository
    let userTaskRepository: UserTaskRepository
    let chatRepository: ChatRepository
    let supabase: SupabaseSDK
    let locationManager: LocationManager
    let pushNotificationService: PushNotificationService
    
    init(authManager: AuthManager,
         supabase: SupabaseSDK,
         locationManager: LocationManager,
         pushNotificationService: PushNotificationService,
         eventRepository: EventRepository,
         userTaskRepository: UserTaskRepository,
         chatRepository: ChatRepository) {
        self.authManager = authManager
        self.supabase = supabase
        self.locationManager = locationManager
        self.pushNotificationService = pushNotificationService
        self.eventRepository = eventRepository
        self.userTaskRepository = userTaskRepository
        self.chatRepository = chatRepository
    }
}
