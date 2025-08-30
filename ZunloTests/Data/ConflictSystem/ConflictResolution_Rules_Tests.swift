//
//  ConflictResolution_Rules_Tests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import XCTest
@testable import Zunlo

final class ConflictResolution_Rules_Tests: XCTestCase {

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

    func test_Rule_anchorPrefersServer_onDoubleEdit() async {
        let id = UUID()
        let now = Date()
        // base rule
        var base = RecurrenceRuleRemote(
            id: id,
            eventId: UUID(),
            freq: "weekly",
            interval: 1,
            byweekday: [2,4],
            until: Date(timeIntervalSince1970: 1000),
            createdAt: now,
            updatedAt: now,
            updatedAtRaw: ts(now)
        )
        
        // server truncates until, bumps version
        var remote = base; remote.until = Date(timeIntervalSince1970: 1100); remote.updatedAt = now.addingTimeInterval(1); remote.version = 2
        // local also tweaks until (competing)
        var local  = base; local.until  = Date(timeIntervalSince1970: 1200); local.updatedAt  = now.addingTimeInterval(2)

        let db = MockDatabaseActor()
        let api = MockSyncAPI(); api.serverRule = remote

        let conflictId = "recurrence_rules:\(id.uuidString)"
        db.seedConflict(.init(
            id: conflictId, table: "recurrence_rules", rowId: id,
            baseVersion: base.version, localVersion: local.version, remoteVersion: remote.version,
            baseJSON: try! encodeJSON(base), localJSON: try! encodeJSON(local), remoteJSON: try! encodeJSON(remote),
            createdAt: now, resolvedAt: nil, attempts: 0, status: .pending
        ))

        let center = makeCenter(db: db, api: api)
        await center.attemptAutoResolve(conflictId: conflictId)

        XCTAssertEqual(db.conflicts[conflictId]?.status, .autoResolved)
        XCTAssertEqual(api.serverRule?.until, remote.until, "server anchor should win on double edit")
    }
}
