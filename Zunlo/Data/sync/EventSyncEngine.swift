//
//  EventSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation
import RealmSwift
import Supabase

final class EventSyncEngine {
    private let db: DatabaseActor
    private let api: SyncAPI
    private let pageSize = 100
    private let tableName = "events"
    
    init(db: DatabaseActor, api: SyncAPI) {
        self.db = db
        self.api = api
    }
    
    func makeRunner() -> SyncRunner<EventRemote, EventInsertPayload, EventUpdatePayload> {
        return makeEventRunner(db: db, api: api)
    }
    
    // Mappers (using your insert/update payloads)
    func eventInsert(_ r: EventRemote) -> EventInsertPayload { EventInsertPayload(remote: r) }
    func eventUpdate(_ r: EventRemote) -> EventUpdatePayload { EventUpdatePayload.full(from: r) }

    func makeEventRunner(db: DatabaseActor, api: SyncAPI) -> SyncRunner<EventRemote, EventInsertPayload, EventUpdatePayload> {
        let spec = SyncSpec<EventRemote, EventInsertPayload, EventUpdatePayload>(
            entityKey: self.tableName,
            pageSize: 100,

            // API
            fetchSince: { ts, id, size in try await api.fetchEventsToSync(sinceTimestamp: ts, sinceID: id, pageSize: size) },
            fetchOne: { id in try await api.fetchEvent(id: id) },
            insertReturning: { payloads in try await api.insertEventsPayloadReturning(payloads) }, // see note below
            updateIfVersionMatches: { row, patch in
                let expected = row.version ?? -1
                return try await api.updateEventIfVersionMatchesPatch(id: row.id, expectedVersion: expected, patch: patch)
            },

            // DB
            readDirty: { try await db.readDirtyEvents().0 }, // your existing return
            applyPage: { rows in try await db.applyPage(for: self.tableName, rows: rows) { realm, rows in
                for r in rows {
                    if let tomb = r.deletedAt {
                        if let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: r.id) {
                            obj.deletedAt = tomb; obj.needsSync = false; obj.version = r.version
                        }
                        continue
                    }
                    let obj = realm.object(ofType: EventLocal.self, forPrimaryKey: r.id) ?? { let o = EventLocal(); o.id = r.id; return o }()
                    obj.getUpdateFields(remote: r)
                    realm.add(obj, update: .modified)
                }
            }},
            markClean: { ids in try await db.markEventsClean(ids) },
            recordConflicts: { items in
                try await db.recordConflicts(.events, items: items, idOf: { $0.id }, localVersion: { $0.version }, remoteVersion: { $0?.version })
            },
            readCursor: { try await db.readCursor(for: self.tableName) },

            // Mappers
            isInsert: { $0.isInsertCandidate },
            makeInsertPayload: eventInsert,
            makeUpdatePayload: eventUpdate
        )
        return SyncRunner(spec: spec)
    }
}
