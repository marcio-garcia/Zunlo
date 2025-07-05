//
//  SwiftDataEventOverrideLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataEventOverrideLocalStore: EventOverrideLocalStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [EventOverrideLocal] {
        try modelContext.fetch(FetchDescriptor<EventOverrideLocal>())
    }

    func deleteAll() throws {
        let all = try fetchAll()
        for item in all { modelContext.delete(item) }
        try modelContext.save()
    }
    
    func fetch(for eventId: UUID) throws -> [EventOverrideLocal] {
        let predicate = #Predicate<EventOverrideLocal> { $0.eventId == eventId }
        return try modelContext.fetch(FetchDescriptor<EventOverrideLocal>(predicate: predicate))
    }

    func save(_ override: EventOverrideLocal) throws {
        modelContext.insert(override)
        try modelContext.save()
    }

    func update(_ override: EventOverrideLocal) throws {
        let id = override.id
        let predicate = #Predicate<EventOverrideLocal> { $0.id == id }
        if let ov = try modelContext.fetch(FetchDescriptor<EventOverrideLocal>(predicate: predicate)).first {

            try modelContext.save()
        }
    }

    func delete(_ override: EventOverrideLocal) throws {
        let id = override.id
        let predicate = #Predicate<EventOverrideLocal> { $0.id == id }
        if let ov = try modelContext.fetch(FetchDescriptor<EventOverrideLocal>(predicate: predicate)).first {
            modelContext.delete(ov)
            try modelContext.save()
        }
    }
}
