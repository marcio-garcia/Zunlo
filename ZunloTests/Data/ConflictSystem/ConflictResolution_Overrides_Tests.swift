//
//  ConflictResolution_Overrides_Tests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import XCTest
@testable import Zunlo

final class ConflictResolution_Overrides_Tests: XCTestCase {

    func makeCenter(db: MockDatabaseActor, api: MockSyncAPI) -> TestConflictResolutionCenter {
        TestConflictResolutionCenter(
            db: db,
            resolvers: [
                TaskConflictResolver(api: api),
                EventConflictResolver(api: api),
                RecurrenceRuleConflictResolver(api: api),
                EventOverrideConflictResolver(api: api)
            ]
        )
    }

    func test_Override_reparent_serverWins() async {
        let id = UUID()
        let oldEvent = UUID()
        let newEvent = UUID()

        let now = Date()
        var base = EventOverrideRemote(
            id: id,
            eventId: oldEvent,
            occurrenceDate: now,
            overriddenTitle: "occ",
            overriddenStartDate: now,
            overriddenEndDate: now,
            isCancelled: false,
            createdAt: now,
            updatedAt: now,
            updatedAtRaw: ts(now),
            version: 1
        )
        var remote = base; remote.eventId = newEvent; remote.updatedAt = now.addingTimeInterval(1); remote.version = 2
        var local  = base; local.eventId  = oldEvent; local.updatedAt  = now.addingTimeInterval(2)

        let db = MockDatabaseActor()
        let api = MockSyncAPI(); api.serverOverride = remote

        let conflictId = "event_overrides:\(id.uuidString)"
        db.seedConflict(.init(
            id: conflictId, table: "event_overrides", rowId: id,
            baseVersion: base.version, localVersion: local.version, remoteVersion: remote.version,
            baseJSON: try! encodeJSON(base), localJSON: try! encodeJSON(local), remoteJSON: try! encodeJSON(remote),
            createdAt: Date(), resolvedAt: nil, attempts: 0, status: .pending
        ))

        let center = makeCenter(db: db, api: api)
        await center.attemptAutoResolve(conflictId: conflictId)

        XCTAssertEqual(db.conflicts[conflictId]?.status, .autoResolved)
        XCTAssertEqual(api.serverOverride?.eventId, newEvent, "server re-parent must be preserved")
    }
}
