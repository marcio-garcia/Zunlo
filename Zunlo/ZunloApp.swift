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
    let sharedModelContainer: ModelContainer
    private let authManager = AuthManager()
    private let eventRepository: EventRepository
    private let supabaseSDK: SupabaseSDK
    
    init() {
        let schema = Schema([EventLocal.self, RecurrenceRuleLocal.self, EventOverrideLocal.self])
        let supabaseConfig = SupabaseConfig(anonKey: EnvConfig.shared.apiKey,
                                            baseURL: URL(string: EnvConfig.shared.apiBaseUrl)!)
        do {
            let container = try ModelContainer(for: schema)
            self.sharedModelContainer = container
            supabaseSDK = SupabaseSDK(config: supabaseConfig)
            self.eventRepository = EventRepositoryFactory.make(supabase: supabaseSDK,
                                                               authManager: authManager,
                                                               modelContext: container.mainContext)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(eventRepository)
        }
        .modelContainer(sharedModelContainer)
    }
}
