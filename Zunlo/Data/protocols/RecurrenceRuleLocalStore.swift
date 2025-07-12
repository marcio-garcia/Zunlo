//
//  RecurrenceRuleLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

protocol RecurrenceRuleLocalStore {
    func fetchAll() async throws -> [RecurrenceRule]
    func fetch(for eventId: UUID) async throws -> [RecurrenceRule]
    func save(_ rule: RecurrenceRuleRemote) async throws
    func update(_ rule: RecurrenceRuleRemote) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
}
