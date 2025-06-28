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
    @StateObject private var authManager = AuthManager()

    init() {
        let schema = Schema([EventLocal.self])
        do {
            let container = try ModelContainer(for: schema)
            self.sharedModelContainer = container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            let eventRepository = EventRepository(modelContext: sharedModelContainer.mainContext,
                                                  authManager: authManager)
            RootView()
                .environmentObject(authManager)
                .environmentObject(eventRepository)
        }
        .modelContainer(sharedModelContainer)
    }
}
