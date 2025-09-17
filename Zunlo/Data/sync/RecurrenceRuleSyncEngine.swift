//
//  RecurrenceRuleSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import Supabase
import RealmSwift

final class RecurrenceRuleSyncEngine {
    private let db: DatabaseActor
    private let api: SyncAPI
    private let center: ConflictResolutionCenter?
    private let pageSize = 100
    private let tableName = "recurrence_rules"
    
    init(db: DatabaseActor, api: SyncAPI, center: ConflictResolutionCenter?) {
        self.db = db
        self.api = api
        self.center = center
    }
    
    func makeRunner() -> SyncRunner<RecurrenceRuleRemote, RecRuleInsertPayload, RecRuleUpdatePayload> {
        return makeRuleRunner(db: db, api: api, center: center)
    }
    
    // Mappers (using your insert/update payloads)
    func rulesInsert(_ r: RecurrenceRuleRemote) -> RecRuleInsertPayload { RecRuleInsertPayload(remote: r) }
    func rulesUpdate(_ r: RecurrenceRuleRemote) -> RecRuleUpdatePayload { RecRuleUpdatePayload.full(from: r) }

    func makeRuleRunner(db: DatabaseActor, api: SyncAPI, center: ConflictResolutionCenter?) -> SyncRunner<RecurrenceRuleRemote, RecRuleInsertPayload, RecRuleUpdatePayload> {
        let spec = SyncSpec<RecurrenceRuleRemote, RecRuleInsertPayload, RecRuleUpdatePayload>(
            entityKey: self.tableName,
            pageSize: 100,

            // API
            fetchSince: { ts, id, size in try await api.fetchRecurrenceRulesToSync(sinceTimestamp: ts, sinceID: id, pageSize: size) },
            fetchOne: { id in try await api.fetchRecurrenceRule(id: id) },
            insertReturning: { payloads in try await api.insertRecRulesPayloadReturning(payloads) }, // see note below
            updateIfVersionMatches: { row, patch in
                let expected = row.version ?? -1
                return try await api.updateRecRuleIfVersionMatchesPatch(id: row.id, expectedVersion: expected, patch: patch)
            },

            // DB
            readDirty: { try await db.readDirtyRecurrenceRules().0 }, // your existing return
            applyPage: { rows in try await db.applyPage(for: self.tableName, rows: rows) { realm, rows in
                for r in rows {
                    if let tomb = r.deletedAt {
                        if let obj = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: r.id) {
                            obj.deletedAt = tomb; obj.needsSync = false; obj.version = r.version
                        }
                        continue
                    }
                    let obj = realm.object(ofType: RecurrenceRuleLocal.self, forPrimaryKey: r.id) ?? {
                        let o = RecurrenceRuleLocal()
                        o.id = r.id
                        return o
                    }()
                    obj.getUpdateFields(remote: r)
                    realm.add(obj, update: .modified)
                }
            }},
            markClean: { ids in try await db.markRecurrenceRulesClean(ids) },
            recordConflicts: { items in
                try await db.recordConflicts(.recurrence_rules, items: items, idOf: { $0.id }, localVersion: { $0.version }, remoteVersion: { $0?.version })
            },
            readCursor: { try await db.readCursor(for: self.tableName) },

            // Mappers
            isInsert: { $0.isInsertCandidate },
            makeInsertPayload: rulesInsert,
            makeUpdatePayload: rulesUpdate
        )
        return SyncRunner(spec: spec, conflictCenter: center)
    }
}
