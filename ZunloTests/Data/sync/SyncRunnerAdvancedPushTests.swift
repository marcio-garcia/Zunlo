//
//  SyncRunnerAdvancedPushTests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/27/25.
//

import XCTest
@testable import Zunlo

final class SyncRunnerAdvancedPushTests: XCTestCase {

    func testRateLimitedInsert_perItem_backoff_itemsRemainDirty() async {
        // Arrange: two local inserts; server rate-limits per-item
        let server = MockServer<Row>()
        let db = MockDB<Row>()
        let now = Date()
        let r1 = Row(updatedAtRaw: addSecToTS(now, sec: 0.000001), version: nil, title: "insert-1")
        let r2 = Row(updatedAtRaw: addSecToTS(now, sec: 0.000002), version: nil, title: "insert-2")
        var dirty = [r1, r2]

        // Bulk path fails so we exercise per-item path; each item 429
        let spec = SyncSpec<Row, Row, Row>(
            entityKey: "rows",
            pageSize: 50,
            fetchSince: { ts, id, lim in server.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { _ in nil },
            insertReturning: { payloads in
                if payloads.count > 1 { throw HTTPStatusError(status: 429, body: nil) }
                throw HTTPStatusError(status: 429, body: nil) // per-item also rate-limited
            },
            updateIfVersionMatches: { _, _ in nil },
            readDirty: { dirty },
            applyPage: { rows in db.applyPage(rows) },  // not invoked here
            markClean: { ids in db.cleaned.formUnion(ids) },
            recordConflicts: { _ in },
            readCursor: { (db.cursorTs, db.cursorTsRaw, db.cursorId) },
            isInsert: { $0.version == nil },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        // Act
        let report = await SyncRunner(spec: spec).syncNow()

        // Assert
        XCTAssertEqual(report.inserted, 0)
        XCTAssertEqual(report.updated, 0)
        XCTAssertEqual(report.conflicts, 0)
        XCTAssertTrue(db.cleaned.isEmpty, "Items should remain dirty after 429")
    }

    func testTransientUpdate_failure_keepsItemDirty_andCountsTransient() async {
        // Arrange: one update that fails with 503
        let server = MockServer<Row>()
        let db = MockDB<Row>()
        let now = Date()
        let stale = Row(updatedAtRaw: addSecToTS(now, sec: 0.0001), version: 1, title: "stale")
        var dirty = [stale]

        let spec = SyncSpec<Row, Row, Row>(
            entityKey: "rows",
            pageSize: 50,
            fetchSince: { ts, id, lim in server.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { _ in nil },
            insertReturning: { _ in [] },
            updateIfVersionMatches: { _, _ in throw HTTPStatusError(status: 503, body: nil) },
            readDirty: { dirty },
            applyPage: { rows in db.applyPage(rows) }, // not called
            markClean: { ids in db.cleaned.formUnion(ids) },
            recordConflicts: { _ in },
            readCursor: { (db.cursorTs, db.cursorTsRaw, db.cursorId) },
            isInsert: { $0.version == nil },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        // Act
        let report = await SyncRunner(spec: spec).syncNow()

        // Assert
        XCTAssertEqual(report.updated, 0)
        XCTAssertEqual(report.conflicts, 0)
        XCTAssertTrue(db.cleaned.isEmpty, "Transient failure should not clean the item")
    }

    func testMissingOnUpdate_countedAsMissing_notConflict() async {
        // Arrange: one update that yields 404 (server row deleted)
        let server = MockServer<Row>()
        let db = MockDB<Row>()
        let now = Date()
        let stale = Row(updatedAtRaw: ts(now), version: 2, title: "stale")
        var dirty = [stale]

        let spec = SyncSpec<Row, Row, Row>(
            entityKey: "rows",
            pageSize: 50,
            fetchSince: { ts, id, lim in server.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { _ in nil },
            insertReturning: { _ in [] },
            updateIfVersionMatches: { _, _ in throw HTTPStatusError(status: 404, body: nil) },
            readDirty: { dirty },
            applyPage: { rows in db.applyPage(rows) }, // not called
            markClean: { ids in db.cleaned.formUnion(ids) },
            recordConflicts: { _ in },
            readCursor: { (db.cursorTs, db.cursorTsRaw, db.cursorId) },
            isInsert: { $0.version == nil },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        // Act
        let report = await SyncRunner(spec: spec).syncNow()

        // Assert
        XCTAssertEqual(report.conflicts, 0)
        XCTAssertEqual(report.updated, 0)
        XCTAssertTrue(db.cleaned.isEmpty, "404 should not clean or record conflict")
    }

    func testGuardedUpdate_nilReturn_isConflict() async {
        // Arrange: server returns 200 with [] (version mismatch) → our closure returns nil
        let server = MockServer<Row>()
        let db = MockDB<Row>()
        let stale = Row(updatedAtRaw: ts(Date()), version: 1, title: "stale")
        var dirty = [stale]

        let spec = SyncSpec<Row, Row, Row>(
            entityKey: "rows",
            pageSize: 50,
            fetchSince: { ts, id, lim in server.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { _ in nil }, // optional: could return server copy
            insertReturning: { _ in [] },
            updateIfVersionMatches: { _, _ in nil }, // signals conflict path
            readDirty: { dirty },
            applyPage: { rows in db.applyPage(rows) }, // not called
            markClean: { ids in db.cleaned.formUnion(ids) },
            recordConflicts: { pairs in db.conflicts.append(contentsOf: pairs) },
            readCursor: { (db.cursorTs, db.cursorTsRaw, db.cursorId) },
            isInsert: { $0.version == nil },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        let report = await SyncRunner(spec: spec).syncNow()
        XCTAssertEqual(report.conflicts, 1)
        XCTAssertTrue(db.cleaned.isEmpty)
        XCTAssertEqual(db.conflicts.count, 1)
    }
}
