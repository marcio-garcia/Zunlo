//
//  SwiftDataEventLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

import Foundation
import SwiftData

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
        modelContext.insert(event)
        try modelContext.save()
    }

    func delete(_ event: EventLocal) throws {
        modelContext.delete(event)
        try modelContext.save()
    }

    func deleteAll() throws {
        let fetchDescriptor = FetchDescriptor<EventLocal>()
        let allEvents = try modelContext.fetch(fetchDescriptor)
        for event in allEvents {
            modelContext.delete(event)
        }
        try modelContext.save()
    }
}
