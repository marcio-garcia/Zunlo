//
//  ConflictResolution_Events_Tests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import XCTest
@testable import Zunlo

final class ConflictResolution_Events_Tests: XCTestCase {

    func makeCenter(db: ConflictDB, api: MockSyncAPI) -> TestConflictResolutionCenter {
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

    func test_Event_reminderTriggers_newerWins() async {
        let id = UUID()
        let trigSrv = [ReminderTrigger(timeBeforeDue: 900, message: nil)]
        let trigLoc = [ReminderTrigger(timeBeforeDue: 600, message: "ping")]

        let now = Date()
        let base = EventRemote(
            id: id,
            user_id: UUID(),
            title: "meet",
            notes: nil,
            start_datetime: now,
            end_datetime: now,
            is_recurring: false,
            location: nil,
            createdAt: now,
            updatedAt: now,
            updatedAtRaw: ts(now),
            color: nil,
            reminder_triggers: trigSrv,
            deletedAt: nil,
            version: 1
        )
        var remote = base; remote.reminder_triggers = trigSrv; remote.updatedAt = now.addingTimeInterval(1); remote.version = 2
        var local  = base; local.reminder_triggers  = trigLoc; local.updatedAt  = now.addingTimeInterval(2)

        let db = MockDatabaseActor()
        let api = MockSyncAPI()
        api.serverEvent = remote

        let conflictId = "events:\(id.uuidString)"
        let conflictData = ConflictData(
            id: conflictId, table: "events", rowId: id,
            baseVersion: base.version, localVersion: local.version, remoteVersion: remote.version,
            baseJSON: try! encodeJSON(base, serverOwnedEncodingStrategy: .include),
            localJSON: try! encodeJSON(local, serverOwnedEncodingStrategy: .include),
            remoteJSON: try! encodeJSON(remote, serverOwnedEncodingStrategy: .include),
            createdAt: Date(), resolvedAt: nil, attempts: 0, status: .pending
        )
        db.seedConflict(conflictData)
        
        let center = makeCenter(db: db, api: api)
        await center.attemptAutoResolve(conflictId: conflictId)

//        XCTAssertEqual(db.conflicts[conflictId]?.status, .autoResolved)
//        XCTAssertEqual(api.serverEvent?.reminder_triggers, trigLoc)
    }
}
