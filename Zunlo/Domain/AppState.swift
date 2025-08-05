//
//  AppState.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SupabaseSDK
import AdStack

final class AppState {
    let authManager: AuthManager
    let eventRepository: EventRepository
    let userTaskRepository: UserTaskRepository
    let chatRepository: ChatRepository
    let supabase: SupabaseSDK
    let locationService: LocationService
    let pushNotificationService: PushNotificationService
    let adManager: AdMobManager
    
    init(authManager: AuthManager,
         supabase: SupabaseSDK,
         locationService: LocationService,
         pushNotificationService: PushNotificationService,
         adManager: AdMobManager,
         eventRepository: EventRepository,
         userTaskRepository: UserTaskRepository,
         chatRepository: ChatRepository) {
        self.authManager = authManager
        self.supabase = supabase
        self.locationService = locationService
        self.pushNotificationService = pushNotificationService
        self.adManager = adManager
        self.eventRepository = eventRepository
        self.userTaskRepository = userTaskRepository
        self.chatRepository = chatRepository
    }
}
