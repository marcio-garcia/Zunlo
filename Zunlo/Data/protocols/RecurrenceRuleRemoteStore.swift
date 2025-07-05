//
//  RecurrenceRuleRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

protocol RecurrenceRuleRemoteStore {
    func fetchAll() async throws -> [RecurrenceRuleRemote]
    func fetch(for eventId: UUID) async throws -> [RecurrenceRuleRemote]
    func save(_ rule: RecurrenceRuleRemote) async throws -> [RecurrenceRuleRemote]
    func update(_ rule: RecurrenceRuleRemote) async throws -> [RecurrenceRuleRemote]
    func delete(_ rule: RecurrenceRuleRemote) async throws -> [RecurrenceRuleRemote]
}
