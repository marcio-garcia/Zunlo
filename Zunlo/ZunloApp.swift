//
//  ZunloApp.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI
import SwiftData
import SupabaseSDK

@main
struct ZunloApp: App {
    private let authManager = AuthManager()
    private let eventRepository: EventRepository
    private let supabaseSDK: SupabaseSDK
    
    init() {
        let supabaseConfig = SupabaseConfig(anonKey: EnvConfig.shared.apiKey,
                                            baseURL: URL(string: EnvConfig.shared.apiBaseUrl)!)
        supabaseSDK = SupabaseSDK(config: supabaseConfig)
        self.eventRepository = EventRepositoryFactory.make(supabase: supabaseSDK,
                                                           authManager: authManager)
    }

    var body: some Scene {
        WindowGroup {
            RootView(eventRepository: eventRepository)
                .environmentObject(authManager)
        }
    }
}
