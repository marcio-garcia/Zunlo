//
//  SwiftDataRecurrenceRuleLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataRecurrenceRuleLocalStore: RecurrenceRuleLocalStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [RecurrenceRuleLocal] {
        try modelContext.fetch(FetchDescriptor<RecurrenceRuleLocal>())
    }
    
    func deleteAll() throws {
        let all = try fetchAll()
        for item in all { modelContext.delete(item) }
        try modelContext.save()
    }
    
    func fetch(for eventId: UUID) throws -> [RecurrenceRuleLocal] {
        let predicate = #Predicate<RecurrenceRuleLocal> { $0.eventId == eventId }
        return try modelContext.fetch(FetchDescriptor<RecurrenceRuleLocal>(predicate: predicate))
    }

    func save(_ rule: RecurrenceRuleLocal) throws {
        modelContext.insert(rule)
        try modelContext.save()
    }

    func update(_ rule: RecurrenceRuleLocal) throws {
        let id = rule.id
        let predicate = #Predicate<RecurrenceRuleLocal> { $0.id == id }
        if let ruleLocal = try modelContext.fetch(FetchDescriptor<RecurrenceRuleLocal>(predicate: predicate)).first {
            ruleLocal.getUpdateFields(rule)
            try modelContext.save()
        }
    }

    func delete(_ rule: RecurrenceRuleLocal) throws {
        let id = rule.id
        let predicate = #Predicate<RecurrenceRuleLocal> { $0.id == id }
        if let ruleLocal = try modelContext.fetch(FetchDescriptor<RecurrenceRuleLocal>(predicate: predicate)).first {
            modelContext.delete(ruleLocal)
            try modelContext.save()
        }
    }
}

