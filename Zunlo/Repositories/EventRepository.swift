//
//  EventRepository.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI
import SwiftData

class EventRepository: ObservableObject {
    private let context: ModelContext
    
    @Published private(set) var events: [EventEntity] = []
    
    init(context: ModelContext) {
        self.context = context
        loadUpcomingEvents()
    }
    
    func loadUpcomingEvents() {
        let today = Calendar.current.startOfDay(for: Date())
        
        let predicate = #Predicate<EventEntity> { event in
            event.dueDate != nil && event.dueDate! >= today
        }
        
        let descriptor = FetchDescriptor(predicate: predicate,
                                         sortBy: [SortDescriptor(\.dueDate)])
        do {
            events = try context.fetch(descriptor)
            print("Fetched events:", events.count)
        } catch {
            print("Failed to fetch events: \(error)")
            events = []
        }
    }
    
    func addEvent(title: String, dueDate: Date?) {
        let event = EventEntity(title: title, dueDate: dueDate)
        context.insert(event)
        try? context.save()
        print("Inserted event:", event.title, event.dueDate as Any)
        loadUpcomingEvents()
    }
    
    func deleteEvent(_ event: EventEntity) {
        context.delete(event)
        loadUpcomingEvents()
    }

    func toggleCompleted(event: EventEntity) {
        event.isCompleted.toggle()
        loadUpcomingEvents()
    }
}
