//
//  ZunloApp.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI
import SwiftData

@main
struct ZunloApp: App {
//    let sharedModelContainer: ModelContainer
//    @StateObject private var repository: EventRepository
    
    init() {
//        let schema = Schema([Event.self])
//        do {
//            let container = try ModelContainer(for: schema)
//            self.sharedModelContainer = container
//            _repository = StateObject(wrappedValue: EventRepository(context: container.mainContext))
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
    }
    
    var body: some Scene {
        WindowGroup {
            AuthView()
//            TimelineScrollView()
//                .environmentObject(repository)
        }
//        .modelContainer(sharedModelContainer)
    }
}
