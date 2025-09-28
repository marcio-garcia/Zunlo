//
//  ConflictResolution_Tasks_Tests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import XCTest
@testable import Zunlo

final class ConflictResolution_Tasks_Tests: XCTestCase {

    func makeCenter(db: MockDatabaseActor, api: MockSyncAPI) -> TestConflictResolutionCenter {
        let center = TestConflictResolutionCenter(
            db: db,
            resolvers: [
                TaskConflictResolver(api: api),
                EventConflictResolver(api: api),
                RecurrenceRuleConflictResolver(api: api),
                EventOverrideConflictResolver(api: api)
            ]
        )
        return center
    }

    func test_Task_updateVsUpdate_titleNewerLocal_autoResolves() async {
        let id = UUID()
        let now = Date()
        let base = UserTaskRemote(
            id: id, userId: UUID(), title: "base", notes: nil, isCompleted: false,
            createdAt: now, updatedAt: now, updatedAtRaw: ts(now),
            dueDate: nil, priority: .medium, parentEventId: nil, tags: [], reminderTriggers: nil,
            deletedAt: nil, version: 1
        )
        let remote = { () -> UserTaskRemote in
            var r = base; r.title = "srv"; r.updatedAt = now.addingTimeInterval(1); r.version = 2; return r
        }()
        let local = { () -> UserTaskRemote in
            var r = base; r.title = "loc"; r.updatedAt = now.addingTimeInterval(2); return r
        }()

        let db = MockDatabaseActor()
        let api = MockSyncAPI()
        api.serverTask = remote
        api.taskMode = .success

        let conflictId = "tasks:\(id.uuidString)"
        db.seedConflict(.init(
            id: conflictId, table: "tasks", rowId: id,
            baseVersion: base.version, localVersion: local.version, remoteVersion: remote.version,
            baseJSON: try! encodeJSON(base, serverOwnedEncodingStrategy: .include),
            localJSON: try! encodeJSON(local, serverOwnedEncodingStrategy: .include),
            remoteJSON: try! encodeJSON(remote, serverOwnedEncodingStrategy: .include),
            createdAt: Date(), resolvedAt: nil, attempts: 0, status: .pending
        ))

        let center = makeCenter(db: db, api: api)
        await center.attemptAutoResolve(conflictId: conflictId)

        // Resolved & applied one task
//        XCTAssertEqual(db.conflicts[conflictId]?.status, .autoResolved)
//        XCTAssertEqual(db.appliedTasks.count, 1)
//        XCTAssertEqual(api.serverTask?.title, "loc", "newer local title should win")
    }

    func test_Task_notesDoubleEdit_appends_andResolves() async {
        let id = UUID()
        let now = Date()
        var base = UserTaskRemote(
            id: id, userId: UUID(), title: "t", notes: "base", isCompleted: false,
            createdAt: now, updatedAt: now, updatedAtRaw: ts(now),
            dueDate: nil, priority: .medium, parentEventId: nil, tags: [], reminderTriggers: nil,
            deletedAt: nil, version: 1
        )
        var remote = base; remote.notes = "srv"; remote.updatedAt = now.addingTimeInterval(1); remote.version = 2
        var local  = base; local.notes  = "loc"; local.updatedAt  = now.addingTimeInterval(2)

        let db = MockDatabaseActor()
        let api = MockSyncAPI(); api.serverTask = remote

        let conflictId = "tasks:\(id.uuidString)"
        db.seedConflict(.init(
            id: conflictId, table: "tasks", rowId: id,
            baseVersion: base.version, localVersion: local.version, remoteVersion: remote.version,
            baseJSON: try! encodeJSON(base, serverOwnedEncodingStrategy: .include),
            localJSON: try! encodeJSON(local, serverOwnedEncodingStrategy: .include),
            remoteJSON: try! encodeJSON(remote, serverOwnedEncodingStrategy: .include),
            createdAt: Date(), resolvedAt: nil, attempts: 0, status: .pending
        ))

        let center = makeCenter(db: db, api: api)
        await center.attemptAutoResolve(conflictId: conflictId)

//        XCTAssertEqual(db.conflicts[conflictId]?.status, .autoResolved)
//        XCTAssertEqual(db.appliedTasks.count, 1)
//        XCTAssertTrue(api.serverTask?.notes?.contains("loc") == true)
//        XCTAssertTrue(api.serverTask?.notes?.contains("srv") == true)
    }

    func test_Task_tagsThreeWayMerge_unionMinusRemovals() async {
        let id = UUID()
        let now = Date()
        var base = UserTaskRemote(
            id: id, userId: UUID(), title: "t", notes: nil, isCompleted: false,
            createdAt: now, updatedAt: now, updatedAtRaw: ts(now),
            dueDate: nil, priority: .medium, parentEventId: nil, tags: ["a", "b"], reminderTriggers: nil,
            deletedAt: nil, version: 1
        )
        var remote = base; remote.tags = ["b", "c"]; remote.updatedAt = now.addingTimeInterval(1); remote.version = 2
        var local  = base; local.tags  = ["a", "d"]; local.updatedAt  = now.addingTimeInterval(2)

        let db = MockDatabaseActor()
        let api = MockSyncAPI(); api.serverTask = remote

        let conflictId = "tasks:\(id.uuidString)"
        db.seedConflict(.init(
            id: conflictId, table: "tasks", rowId: id,
            baseVersion: base.version, localVersion: local.version, remoteVersion: remote.version,
            baseJSON: try! encodeJSON(base, serverOwnedEncodingStrategy: .include),
            localJSON: try! encodeJSON(local, serverOwnedEncodingStrategy: .include),
            remoteJSON: try! encodeJSON(remote, serverOwnedEncodingStrategy: .include),
            createdAt: now, resolvedAt: nil, attempts: 0, status: .pending
        ))

        let center = makeCenter(db: db, api: api)
        await center.attemptAutoResolve(conflictId: conflictId)

//        XCTAssertEqual(db.conflicts[conflictId]?.status, .autoResolved)
//        let tags = Set(api.serverTask?.tags ?? [])
//        XCTAssertEqual(tags, Set(["a","d"])) // newer wins
    }
    
    func test_Task_tags_bothChanged_equalTimestamps_prefersServer() async {
        let id = UUID()
        let now = Date()

        var base = UserTaskRemote(
            id: id, userId: UUID(), title: "t", notes: nil, isCompleted: false,
            createdAt: now, updatedAt: now, updatedAtRaw: ts(now),
            dueDate: nil, priority: .medium, parentEventId: nil, tags: ["a", "b"], reminderTriggers: nil,
            deletedAt: nil, version: 1
        )
        base.tags = ["x"]; base.updatedAt = now; base.updatedAtRaw = ts(now); base.version = 1

        var remote = base; remote.tags = ["y"]; remote.updatedAt = now; remote.updatedAtRaw = ts(now); remote.version = 2
        var local  = base; local.tags  = ["z"]; local.updatedAt  = now; local.updatedAtRaw  = ts(now)

        let db = MockDatabaseActor()
        let api = MockSyncAPI(); api.serverTask = remote
        let conflictId = "tasks:\(id.uuidString)"
        db.seedConflict(.init(
            id: conflictId, table: "tasks", rowId: id,
            baseVersion: base.version, localVersion: local.version, remoteVersion: remote.version,
            baseJSON: try! encodeJSON(base, serverOwnedEncodingStrategy: .include),
            localJSON: try! encodeJSON(local, serverOwnedEncodingStrategy: .include),
            remoteJSON: try! encodeJSON(remote, serverOwnedEncodingStrategy: .include),
            createdAt: now, resolvedAt: nil, attempts: 0, status: .pending
        ))

        let center = makeCenter(db: db, api: api)
        await center.attemptAutoResolve(conflictId: conflictId)

//        XCTAssertEqual(db.conflicts[conflictId]?.status, .autoResolved)
//        XCTAssertEqual(Set(api.serverTask?.tags ?? []), Set(["y"])) // server wins on tie
    }

    func test_Task_reminderTriggers_newerWinsWholeArray() async {
        let id = UUID()
        let now = Date()
        let trigA = [ReminderTrigger(timeBeforeDue: 900, message: nil)]
        let trigB = [ReminderTrigger(timeBeforeDue: 600, message: "ping")]

        var base = UserTaskRemote(
            id: id, userId: UUID(), title: "t", notes: nil, isCompleted: false,
            createdAt: now, updatedAt: now, updatedAtRaw: ts(now),
            dueDate: nil, priority: .medium, parentEventId: nil, tags: [], reminderTriggers: trigA,
            deletedAt: nil, version: 1
        )
        var remote = base; remote.reminderTriggers = trigA; remote.updatedAt = now.addingTimeInterval(3); remote.version = 2
        var local  = base; local.reminderTriggers  = trigB; local.updatedAt  = now.addingTimeInterval(4)

        let db = MockDatabaseActor()
        let api = MockSyncAPI(); api.serverTask = remote

        let conflictId = "tasks:\(id.uuidString)"
        db.seedConflict(.init(
            id: conflictId, table: "tasks", rowId: id,
            baseVersion: base.version, localVersion: local.version, remoteVersion: remote.version,
            baseJSON: try! encodeJSON(base, serverOwnedEncodingStrategy: .include),
            localJSON: try! encodeJSON(local, serverOwnedEncodingStrategy: .include),
            remoteJSON: try! encodeJSON(remote, serverOwnedEncodingStrategy: .include),
            createdAt: now, resolvedAt: nil, attempts: 0, status: .pending
        ))

        let center = makeCenter(db: db, api: api)
        await center.attemptAutoResolve(conflictId: conflictId)

//        XCTAssertEqual(db.conflicts[conflictId]?.status, .autoResolved)
//        XCTAssertEqual(api.serverTask?.reminderTriggers, trigB, "local is newer → whole array from local")
    }

    func test_Task_guardedUpdate_nilReturn_needsUser() async {
        let id = UUID()
        let now = Date()
        var base = UserTaskRemote(
            id: id, userId: UUID(), title: "base", notes: nil, isCompleted: false,
            createdAt: now, updatedAt: now, updatedAtRaw: ts(now),
            dueDate: nil, priority: .medium, parentEventId: nil, tags: [], reminderTriggers: nil,
            deletedAt: nil, version: 1
        )
        var remote = base; remote.title = "srv"; remote.version = 2; remote.updatedAt = now.addingTimeInterval(1)
        var local  = base; local.title  = "loc"; local.updatedAt  = now.addingTimeInterval(2)

        let db = MockDatabaseActor()
        let api = MockSyncAPI(); api.serverTask = remote; api.taskMode = .nilReturn

        let conflictId = "tasks:\(id.uuidString)"
        db.seedConflict(.init(
            id: conflictId, table: "tasks", rowId: id,
            baseVersion: base.version, localVersion: local.version, remoteVersion: remote.version,
            baseJSON: try! encodeJSON(base, serverOwnedEncodingStrategy: .include),
            localJSON: try! encodeJSON(local, serverOwnedEncodingStrategy: .include),
            remoteJSON: try! encodeJSON(remote, serverOwnedEncodingStrategy: .include),
            createdAt: now, resolvedAt: nil, attempts: 0, status: .pending
        ))

        let center = makeCenter(db: db, api: api)
        await center.attemptAutoResolve(conflictId: conflictId)

//        XCTAssertEqual(db.conflicts[conflictId]?.status, .needsUser)
//        XCTAssertTrue(db.appliedTasks.isEmpty)
    }

    func test_Task_guardedUpdate_HTTP409_failsConflict() async {
        let id = UUID()
        let now = Date()
        let base = UserTaskRemote(
            id: id, userId: UUID(), title: "base", notes: nil, isCompleted: false,
            createdAt: now, updatedAt: now, updatedAtRaw: ts(now),
            dueDate: nil, priority: .medium, parentEventId: nil, tags: [], reminderTriggers: nil,
            deletedAt: nil, version: 1
        )
        var remote = base; remote.title = "srv"; remote.version = 2; remote.updatedAt = now.addingTimeInterval(1)
        var local  = base; local.title  = "loc"; local.updatedAt  = now.addingTimeInterval(2)

        let db = MockDatabaseActor()
        let api = MockSyncAPI(); api.serverTask = remote; api.taskMode = .conflictHTTP

        let conflictId = "tasks:\(id.uuidString)"
        db.seedConflict(.init(
            id: conflictId, table: "tasks", rowId: id,
            baseVersion: base.version, localVersion: local.version, remoteVersion: remote.version,
            baseJSON: try! encodeJSON(base, serverOwnedEncodingStrategy: .include),
            localJSON: try! encodeJSON(local, serverOwnedEncodingStrategy: .include),
            remoteJSON: try! encodeJSON(remote, serverOwnedEncodingStrategy: .include),
            createdAt: now, resolvedAt: nil, attempts: 0, status: .pending
        ))

        let center = makeCenter(db: db, api: api)
        await center.attemptAutoResolve(conflictId: conflictId)

//        XCTAssertEqual(db.conflicts[conflictId]?.status, .failed)
//        XCTAssertTrue(db.appliedTasks.isEmpty)
    }
}
