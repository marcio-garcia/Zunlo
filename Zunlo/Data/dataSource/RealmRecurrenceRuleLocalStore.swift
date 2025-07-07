//
//  RealmRecurrenceRuleLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/7/25.
//

import Foundation
import RealmSwift

final class RealmRecurrenceRuleLocalStore: RecurrenceRuleLocalStore {
    // MARK: - Fetch All (Background)
    func fetchAll() async throws -> [RecurrenceRule] {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let rulesLocal = Array(realm.objects(RecurrenceRuleLocal.self))
            return rulesLocal.map { RecurrenceRule(local: $0) }
        }.value
    }
    
    // MARK: - Fetch By eventId (Background)
    func fetch(for eventId: UUID) async throws -> [RecurrenceRule] {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let results = realm.objects(RecurrenceRuleLocal.self).where { $0.eventId == eventId }
            let rulesLocal = Array(results)
            return rulesLocal.map { RecurrenceRule(local: $0) }
        }.value
    }
    
    // MARK: - Save or Update (Background)
    func save(_ ruleRemote: RecurrenceRuleRemote) async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let rule = RecurrenceRuleLocal(remote: ruleRemote)
            try realm.write {
                realm.add(rule, update: .all)
            }
        }.value
    }

    // MARK: - Update By Value (Preferred)
    func update(_ ruleRemote: RecurrenceRuleRemote) async throws {
        let ruleID = ruleRemote.id // pass only the ID
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            guard let existing = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: ruleID) else { return }
            try realm.write {
                existing.getUpdateFields(ruleRemote)
            }
        }.value
    }
    
    // MARK: - Delete (by object)
    func delete(id: UUID) async throws {
        let ruleID = id
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            guard let obj = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: ruleID) else { return }
            try realm.write {
                realm.delete(obj)
            }
        }.value
    }

    // MARK: - Delete All
    func deleteAll() async throws {
        try await Task.detached(priority: .background) {
            let realm = try Realm()
            let all = realm.objects(RecurrenceRuleLocal.self)
            try realm.write {
                realm.delete(all)
            }
        }.value
    }
}
