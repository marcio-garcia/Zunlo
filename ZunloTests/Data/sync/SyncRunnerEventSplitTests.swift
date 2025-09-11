//
//  SyncRunnerEventSplitTests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/27/25.
//

import XCTest
@testable import Zunlo

final class SyncRunnerEventSplitTests: XCTestCase {

    /// Simulates “Edit this and future occurrences”:
    /// - Events: E1 updated (truncated) + E2 created (new series)
    /// - Recurrence rules: RR1 (for E1) updated (truncated) + RR2 created (for E2)
    /// - Overrides: moved from E1 → E2 and updated
    func testEventSplit_thisAndFuture_includesRecurrenceRules() async {
        // Deterministic IDs for ordering and assertions
        let e1ID  = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA1")!
        let e2ID  = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA2")!
        let rr1ID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCC1")!
        let rr2ID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCC2")!
        let ov1ID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBB1")!
        let ov2ID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBB2")!

        // ---- Server snapshots AFTER split ----
        // Events
        let now = Date()
        let e1_truncated = Row(id: e1ID, updatedAtRaw: addSecToTS(now, sec: 0.0001),
                               version: 2, title: "Event E1 (truncated)", parentId: nil)
        let e2_new      = Row(id: e2ID, updatedAtRaw: addSecToTS(now, sec: 0.000101),
                               version: 1, title: "Event E2 (new series)", parentId: nil)

        // Recurrence rules (parentId == owning event)
        let rr1_truncated = Row(id: rr1ID, updatedAtRaw: addSecToTS(now, sec: 0.0002),
                                version: 2, title: "Rule E1 (truncated)", parentId: e1ID)
        let rr2_new       = Row(id: rr2ID, updatedAtRaw: addSecToTS(now, sec: 0.000201),
                                version: 1, title: "Rule E2 (new)", parentId: e2ID)

        // Overrides moved to E2
        let ov1_moved   = Row(id: ov1ID, updatedAtRaw: addSecToTS(now, sec: 0.0003),
                              version: 2, title: "Override A@new", parentId: e2ID)
        let ov2_moved   = Row(id: ov2ID, updatedAtRaw: addSecToTS(now, sec: 0.000301),
                              version: 2, title: "Override B@new", parentId: e2ID)

        // ---- Servers ----
        let eventServer = MockServer<Row>();          eventServer.seed([e1_truncated, e2_new])
        let ruleServer  = MockServer<Row>();          ruleServer.seed([rr1_truncated, rr2_new])
        let ovServer    = MockServer<Row>();          ovServer.seed([ov1_moved, ov2_moved])

        // ---- Local DBs (in-memory) ----
        let eventDB = MockDB<Row>()
        let ruleDB  = MockDB<Row>()
        let ovDB    = MockDB<Row>()
        let noDirty: [Row] = []

        // ---- Specs ----
        // Events (pull-only)
        let evSpec = SyncSpec<Row, Row, Row>(
            entityKey: "events",
            pageSize: 50,
            fetchSince: { ts, id, lim in eventServer.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { id in eventServer.rows.first(where: { $0.id == id }) },
            insertReturning: { _ in [] },
            updateIfVersionMatches: { _, _ in nil },
            readDirty: { noDirty },
            applyPage: { rows in eventDB.applyPage(rows) },
            markClean: { _ in },
            recordConflicts: { _ in },
            readCursor: { (eventDB.cursorTs, eventDB.cursorTsRaw, eventDB.cursorId) },
            isInsert: { _ in true },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        // Recurrence rules (pull-only)
        let rrSpec = SyncSpec<Row, Row, Row>(
            entityKey: "recurrence_rules",
            pageSize: 50,
            fetchSince: { ts, id, lim in ruleServer.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { id in ruleServer.rows.first(where: { $0.id == id }) },
            insertReturning: { _ in [] },
            updateIfVersionMatches: { _, _ in nil },
            readDirty: { noDirty },
            applyPage: { rows in ruleDB.applyPage(rows) },
            markClean: { _ in },
            recordConflicts: { _ in },
            readCursor: { (ruleDB.cursorTs, ruleDB.cursorTsRaw, ruleDB.cursorId) },
            isInsert: { _ in true },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        // Overrides (pull-only)
        let ovSpec = SyncSpec<Row, Row, Row>(
            entityKey: "event_overrides",
            pageSize: 50,
            fetchSince: { ts, id, lim in ovServer.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { id in ovServer.rows.first(where: { $0.id == id }) },
            insertReturning: { _ in [] },
            updateIfVersionMatches: { _, _ in nil },
            readDirty: { noDirty },
            applyPage: { rows in ovDB.applyPage(rows) },
            markClean: { _ in },
            recordConflicts: { _ in },
            readCursor: { (ovDB.cursorTs, ovDB.cursorTsRaw, ovDB.cursorId) },
            isInsert: { _ in true },
            makeInsertPayload: { $0 },
            makeUpdatePayload: { $0 }
        )

        // ---- Act: run in the order your app would ----
        _ = try? await SyncRunner(spec: evSpec).syncNow()
        _ = try? await SyncRunner(spec: rrSpec).syncNow()
        _ = try? await SyncRunner(spec: ovSpec).syncNow()

        // ---- Assert: Events ----
        let e1Local = eventDB.applied[e1ID]!
        let e2Local = eventDB.applied[e2ID]!
        XCTAssertEqual(e1Local.title, "Event E1 (truncated)")
        XCTAssertEqual(e2Local.title, "Event E2 (new series)")
        XCTAssertEqual(eventDB.cursorTsRaw, e2_new.updatedAtRaw)

        // ---- Assert: Recurrence Rules ----
        let rr1Local = ruleDB.applied[rr1ID]!
        let rr2Local = ruleDB.applied[rr2ID]!
        XCTAssertEqual(rr1Local.title, "Rule E1 (truncated)")
        XCTAssertEqual(rr1Local.parentId, e1ID, "Old rule should still point to E1")
        XCTAssertEqual(rr2Local.title, "Rule E2 (new)")
        XCTAssertEqual(rr2Local.parentId, e2ID, "New rule should point to E2")
        XCTAssertEqual(ruleDB.cursorTsRaw, rr2_new.updatedAtRaw)

        // ---- Assert: Overrides ----
        let ov1Local = ovDB.applied[ov1ID]!
        let ov2Local = ovDB.applied[ov2ID]!
        XCTAssertEqual(ov1Local.parentId, e2ID)
        XCTAssertEqual(ov2Local.parentId, e2ID)
        XCTAssertEqual(ovDB.cursorTsRaw, ov2_moved.updatedAtRaw)
    }
}
