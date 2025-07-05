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

    func fetchAll() throws -> [EventLocal] {
        let fetchDescriptor = FetchDescriptor<EventLocal>(sortBy: [SortDescriptor(\.startDate, order: .forward)])
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
        if let ev = try modelContext.fetch(fetchDescriptor).first {
            ev.getUpdateFields(event)
            // No need to update relationships here—handled separately if needed
            try modelContext.save()
        }
    }

    func delete(_ event: EventLocal) throws {
        let id = event.id
        let predicate = #Predicate<EventLocal> { $0.id == id }
        if let ev = try modelContext.fetch(FetchDescriptor<EventLocal>(predicate: predicate)).first {
            modelContext.delete(ev)
            try modelContext.save()
        }
    }

    func deleteAll() throws {
        let allEvents = try modelContext.fetch(FetchDescriptor<EventLocal>())
        for event in allEvents { modelContext.delete(event) }
        try modelContext.save()
    }

    func deleteAll(for userId: UUID) throws {
        let predicate = #Predicate<EventLocal> { $0.userId == userId }
        for event in try modelContext.fetch(FetchDescriptor<EventLocal>(predicate: predicate)) {
            modelContext.delete(event)
        }
        try modelContext.save()
    }
}
