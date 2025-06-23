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
    
    @Published private(set) var events: [Event] = []
    
    init(context: ModelContext) {
        self.context = context
        loadUpcomingEvents()
    }
    
    func loadUpcomingEvents() {
        let today = Calendar.current.startOfDay(for: Date())
        
        let predicate = #Predicate<Event> { event in
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
        let event = Event(title: title, dueDate: dueDate)
        context.insert(event)
        try? context.save()
        print("Inserted event:", event.title, event.dueDate as Any)
        loadUpcomingEvents()
    }
    
    func deleteEvent(_ event: Event) {
        context.delete(event)
        loadUpcomingEvents()
    }

    func toggleCompleted(event: Event) {
        event.isCompleted.toggle()
        loadUpcomingEvents()
    }
}
