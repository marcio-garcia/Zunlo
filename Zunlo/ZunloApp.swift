//
//  ZunloApp.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI
import SwiftData

//@main
//struct ZunloApp: App {
//    let sharedModelContainer: ModelContainer
//    @StateObject private var repository: EventRepository
//    
//    init() {
//        let schema = Schema([EventEntity.self])
//        do {
//            let container = try ModelContainer(for: schema)
//            self.sharedModelContainer = container
//            _repository = StateObject(wrappedValue: EventRepository(modelContext: container.mainContext))
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }
//    
//    var body: some Scene {
//        WindowGroup {
//            TimelineScrollView()
//                .environmentObject(repository)
//        }
//        .modelContainer(sharedModelContainer)
//    }
//}

@main
struct ZunloApp: App {
    let sharedModelContainer: ModelContainer
    private let authManager = AuthManager()
    private let eventRepository: EventRepository
    
    init() {
        let schema = Schema([EventLocal.self])
        do {
            let container = try ModelContainer(for: schema)
            self.sharedModelContainer = container
            self.eventRepository = EventRepository(modelContext: container.mainContext, authManager: authManager)
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
