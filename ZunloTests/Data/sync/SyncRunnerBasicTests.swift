//
//  SyncRunnerBasicTests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/27/25.
//

import XCTest
@testable import Zunlo

final class SyncRunnerBasicTests: XCTestCase {

    func testCursorAdvances_withEqualTimestamps_noDuplicates() async {
        // Arrange
        let server = MockServer<Row>()
        let t = ts(Date())
        let a = Row(id: UUID(uuidString: "CA4E0E79-B086-44A0-95BB-F45B5B866B75")!, updatedAtRaw: t, title: "A")
        let b = Row(id: UUID(uuidString: "56539C0A-4EB3-4FDA-9F21-3A2B4AE33B40")!, updatedAtRaw: t, title: "B")
        let c = Row(id: UUID(uuidString: "39826302-F229-41A0-951A-F8793232F089")!, updatedAtRaw: t, title: "C")
        server.seed([a,b,c])

        let db = MockDB<Row>()
        let dirty: [Row] = [] // no push in this test

        let spec = SyncSpec<Row, Row, Row>(
            entityKey: "rows",
            pageSize: 2,
            fetchSince: { ts, id, lim in server.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { id in server.rows.first(where: {$0.id == id}) },
            insertReturning: { payloads in payloads },  // not used
            updateIfVersionMatches: { _, _ in nil },    // not used
            readDirty: { dirty },
            applyPage: { rows in db.applyPage(rows) },
            markClean: { _ in },
            recordConflicts: { _ in },
            readCursor: { (db.cursorTs, db.cursorTsRaw, db.cursorId) },
            isInsert: { _ in true },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        let runner = SyncRunner(spec: spec)

        // Act
        let report = try? await runner.syncNow()

        // Assert
        XCTAssertEqual(report?.pulled, 3)
        XCTAssertEqual(db.applied.count, 3)
        XCTAssertEqual(db.cursorTsRaw, c.updatedAtRaw)
        XCTAssertEqual(db.cursorId, a.id)
    }

    func testTombstone_softDelete_applied_and_not_retried() async {
        let server = MockServer<Row>()
        let now = Date()
        let t1 = ts(now)
        let t2 = addSecToTS(now, sec: 3600)
        let live = Row(updatedAtRaw: t1, title: "Live")
        let tomb = Row(updatedAtRaw: t2, deletedAt: Date(), version: 2, title: "Deleted")
        server.seed([live, tomb])

        let db = MockDB<Row>()
        let spec = SyncSpec<Row, Row, Row>(
            entityKey: "rows",
            pageSize: 100,
            fetchSince: { ts, id, lim in server.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { id in server.rows.first(where: {$0.id == id}) },
            insertReturning: { _ in [] },
            updateIfVersionMatches: { _, _ in nil },
            readDirty: { [] },
            applyPage: { rows in db.applyPage(rows) },
            markClean: { _ in },
            recordConflicts: { _ in },
            readCursor: { (db.cursorTs, db.cursorTsRaw, db.cursorId) },
            isInsert: { _ in true },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        let report = try? await SyncRunner(spec: spec).syncNow()
        XCTAssertEqual(report?.pulled, 2)
        XCTAssertNotNil(db.applied[tomb.id]?.deletedAt)
    }

    func testGuardedUpdate_conflict_counted_and_no_update_applied() async {
        let server = MockServer<Row>()
        let t = ts(Date())
        let existing = Row(updatedAtRaw: t, version: 2, title: "Existing")
        server.seed([existing])

        let db = MockDB<Row>()
        let dirty = [ Row(id: existing.id, updatedAtRaw: t, version: 1, title: "LocalEdit") ] // stale version

        let spec = SyncSpec<Row, Row, Row>(
            entityKey: "rows",
            pageSize: 100,
            fetchSince: { ts,id,lim in server.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { id in server.rows.first(where: {$0.id == id}) },
            insertReturning: { _ in [] },
            updateIfVersionMatches: { _,_ in throw HTTPStatusError(status: 409, body: nil) },
            readDirty: { dirty },
            applyPage: { rows in db.applyPage(rows) },
            markClean: { ids in db.cleaned.formUnion(ids) },
            recordConflicts: { pairs in db.conflicts.append(contentsOf: pairs) },
            readCursor: { (db.cursorTs, db.cursorTsRaw, db.cursorId) },
            isInsert: { $0.version == nil },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        let report = try? await SyncRunner(spec: spec).syncNow()
        XCTAssertEqual(report?.inserted, 0)
        XCTAssertEqual(report?.updated, 0)
        XCTAssertEqual(report?.conflicts, 1)
        XCTAssertEqual(db.cleaned.contains(existing.id), false, "Should not mark clean on conflict")
        XCTAssertEqual(db.conflicts.count, 1)
    }

    func testInsert_duplicate_conflict_recorded() async {
        let server = MockServer<Row>()
        let db = MockDB<Row>()
        let now = Date()
        let existing = Row(updatedAtRaw: addSecToTS(now, sec: 0.000001), title: "on server")
        server.seed([existing])

        let duplicate = Row(id: existing.id, updatedAtRaw: ts(now), title: "duplicate local")

        let dirty = [duplicate]

        let spec = SyncSpec<Row, Row, Row>(
            entityKey: "rows", pageSize: 100,
            fetchSince: { ts,id,lim in server.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { id in server.rows.first(where: {$0.id == id}) },
            insertReturning: { _ in throw HTTPStatusError(status: 409, body: nil) },
            updateIfVersionMatches: { _,_ in nil },
            readDirty: { dirty },
            applyPage: { rows in db.applyPage(rows) },
            markClean: { ids in db.cleaned.formUnion(ids) },
            recordConflicts: { pairs in db.conflicts.append(contentsOf: pairs) },
            readCursor: { (db.cursorTs, db.cursorTsRaw, db.cursorId) },
            isInsert: { $0.version == nil },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        let report = try? await SyncRunner(spec: spec).syncNow()
        XCTAssertEqual(report?.conflicts, 1)
        XCTAssertTrue(db.conflicts.contains { $0.0.id == duplicate.id })
        XCTAssertFalse(db.cleaned.contains(duplicate.id))
    }

    func testPull_stops_when_empty_no_infinite_loop() async {
        let server = MockServer<Row>() // empty
        let db = MockDB<Row>()
        let spec = SyncSpec<Row, Row, Row>(
            entityKey: "rows", pageSize: 50,
            fetchSince: { ts,id,lim in server.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { _ in nil },
            insertReturning: { _ in [] },
            updateIfVersionMatches: { _,_ in nil },
            readDirty: { [] },
            applyPage: { rows in db.applyPage(rows) },
            markClean: { _ in },
            recordConflicts: { _ in },
            readCursor: { (db.cursorTs, db.cursorTsRaw, db.cursorId) },
            isInsert: { _ in true },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )
        let report = try? await SyncRunner(spec: spec).syncNow()
        XCTAssertEqual(report?.pulled, 0)
    }
}
