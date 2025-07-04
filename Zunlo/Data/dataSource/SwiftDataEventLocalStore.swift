//
//  SwiftDataEventLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataEventLocalStore: EventLocalStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch() throws -> [EventLocal] {
        let fetchDescriptor = FetchDescriptor<EventLocal>(sortBy: [SortDescriptor(\.dueDate, order: .forward)])
        return try modelContext.fetch(fetchDescriptor)
    }

    func save(_ event: EventLocal) throws {
        modelContext.insert(event)
        try modelContext.save()
    }

    func update(_ event: EventLocal) throws {
        let id = event.id
        let predicate = #Predicate<EventLocal> { $0.id == id }
        let fetchDescriptor = FetchDescriptor<EventLocal>(predicate: predicate)
        let events = try modelContext.fetch(fetchDescriptor)
        if let ev = events.first {
            ev.getUpdateFields(event)
            try modelContext.save()
        }
    }

    func delete(_ event: EventLocal) throws {
        let id = event.id
        let predicate = #Predicate<EventLocal> { $0.id == id }
        let fetchDescriptor = FetchDescriptor<EventLocal>(predicate: predicate)
        let events = try modelContext.fetch(fetchDescriptor)
        if let ev = events.first {
            modelContext.delete(ev)
            try modelContext.save()
        }
    }

    func deleteAll() throws {
        let fetchDescriptor = FetchDescriptor<EventLocal>()
        let allEvents = try modelContext.fetch(fetchDescriptor)
        for event in allEvents {
            modelContext.delete(event)
        }
        try modelContext.save()
    }
    
    func deleteAll(for userId: UUID) throws {
        let predicate = #Predicate<EventLocal> { $0.userId == userId }
        let fetchDescriptor = FetchDescriptor<EventLocal>(predicate: predicate)
        let events = try modelContext.fetch(fetchDescriptor)
        for event in events {
            modelContext.delete(event)
        }
        try modelContext.save()
    }
}
