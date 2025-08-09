//
//  AppState.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SupabaseSDK
import AdStack

final class AppState {
    static let shared = AppState()
    
    var authManager: AuthManager?
    var eventRepository: EventRepository?
    var userTaskRepository: UserTaskRepository?
    var chatRepository: ChatRepository?
    var supabase: SupabaseSDK?
    var locationService: LocationService?
    var pushNotificationService: PushNotificationService?
    var adManager: AdMobManager?
    
    private init() {}
    
//    init(authManager: AuthManager,
//         supabase: SupabaseSDK,
//         locationService: LocationService,
//         pushNotificationService: PushNotificationService,
//         adManager: AdMobManager,
//         eventRepository: EventRepository,
//         userTaskRepository: UserTaskRepository,
//         chatRepository: ChatRepository) {
//        self.authManager = authManager
//        self.supabase = supabase
//        self.locationService = locationService
//        self.pushNotificationService = pushNotificationService
//        self.adManager = adManager
//        self.eventRepository = eventRepository
//        self.userTaskRepository = userTaskRepository
//        self.chatRepository = chatRepository
//    }
}
