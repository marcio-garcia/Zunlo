//
//  RecurrenceRuleLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

@MainActor
protocol RecurrenceRuleLocalStore {
    func fetchAll() throws -> [RecurrenceRuleLocal]
    func fetch(for eventId: UUID) throws -> [RecurrenceRuleLocal]
    func save(_ rule: RecurrenceRuleLocal) throws
    func update(_ rule: RecurrenceRuleLocal) throws
    func delete(_ rule: RecurrenceRuleLocal) throws
    func deleteAll() throws
}
