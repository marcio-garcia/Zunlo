//
//  EventOverrideSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import Supabase
import RealmSwift

final class EventOverrideSyncEngine {
    private let db: DatabaseActor
    private let api: SyncAPI
    private let pageSize = 100
    private let tableName = "event_overrides"

    init(db: DatabaseActor, api: SyncAPI) {
        self.db = db
        self.api = api
    }

    func makeRunner() -> SyncRunner<EventOverrideRemote, EventOverrideInsertPayload, EventOverrideUpdatePayload> {
        return makeOverrideRunner(db: db, api: api)
    }
    
    // Mappers (using your insert/update payloads)
    func overrideInsert(_ r: EventOverrideRemote) -> EventOverrideInsertPayload { EventOverrideInsertPayload(remote: r) }
    func overrideUpdate(_ r: EventOverrideRemote) -> EventOverrideUpdatePayload { EventOverrideUpdatePayload.full(from: r) }

    func makeOverrideRunner(db: DatabaseActor, api: SyncAPI) -> SyncRunner<EventOverrideRemote, EventOverrideInsertPayload, EventOverrideUpdatePayload> {
        let spec = SyncSpec<EventOverrideRemote, EventOverrideInsertPayload, EventOverrideUpdatePayload>(
            entityKey: self.tableName,
            pageSize: 100,

            // API
            fetchSince: { ts, id, size in try await api.fetchEventOverridesToSync(sinceTimestamp: ts, sinceID: id, pageSize: size) },
            fetchOne: { id in try await api.fetchEventOverride(id: id) },
            insertReturning: { payloads in try await api.insertOverridesPayloadReturning(payloads) }, // see note below
            updateIfVersionMatches: { row, patch in
                let expected = row.version ?? -1
                return try await api.updateOverrideIfVersionMatchesPatch(id: row.id, expectedVersion: expected, patch: patch)
            },

            // DB
            readDirty: { try await db.readDirtyEventOverrides().0 }, // your existing return
            applyPage: { rows in try await db.applyPage(for: self.tableName, rows: rows) { realm, rows in
                for r in rows {
                    if let tomb = r.deletedAt {
                        if let obj = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: r.id) {
                            obj.deletedAt = tomb; obj.needsSync = false; obj.version = r.version
                        }
                        continue
                    }
                    let obj = realm.object(ofType: EventOverrideLocal.self, forPrimaryKey: r.id) ?? { let o = EventOverrideLocal(); o.id = r.id; return o }()
                    obj.getUpdateFields(remote: r)
                    realm.add(obj, update: .modified)
                }
            }},
            markClean: { ids in try await db.markEventOverridesClean(ids) },
            recordConflicts: { items in
                try await db.recordConflicts(.tasks, items: items, idOf: { $0.id }, localVersion: { $0.version }, remoteVersion: { $0?.version })
            },
            readCursor: { try await db.readCursor(for: self.tableName) },

            // Mappers
            isInsert: { $0.isInsertCandidate },
            makeInsertPayload: overrideInsert,
            makeUpdatePayload: overrideUpdate
        )
        return SyncRunner(spec: spec)
    }
}
