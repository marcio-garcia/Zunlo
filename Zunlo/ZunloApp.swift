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
    @StateObject private var eventRepository: EventRepository
    @StateObject private var authCoordinator = AppAuthCoordinator()

    init() {
        let schema = Schema([EventLocal.self])
        do {
            let container = try ModelContainer(for: schema)
            self.sharedModelContainer = container
            _eventRepository = StateObject(wrappedValue: EventRepository(modelContext: container.mainContext))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authCoordinator)
                .environmentObject(eventRepository)
        }
        .modelContainer(sharedModelContainer)
    }
}
