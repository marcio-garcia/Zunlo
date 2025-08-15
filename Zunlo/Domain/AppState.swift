//
//  AppState.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SupabaseSDK
import AdStack
import Supabase

final class AppState {
    static let shared = AppState()
    
    var authManager: AuthManager?
    var localDB: DatabaseActor?
    var eventRepository: EventRepository?
    var userTaskRepository: UserTaskRepository?
    var chatRepository: ChatRepository?
    var supabase: SupabaseSDK?
    var locationService: LocationService?
    var pushNotificationService: PushNotificationService?
    var adManager: AdMobManager?
    var suggestionEngine: SuggestionEngine?
    var supabaseClient: SupabaseClient?
    
    private init() {}
}
