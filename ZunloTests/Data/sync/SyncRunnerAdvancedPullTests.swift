//
//  SyncRunnerAdvancedPullTests.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/27/25.
//

import XCTest
@testable import Zunlo

final class SyncRunnerAdvancedPullTests: XCTestCase {

    func testInterleavedEqualTimestampsAcrossPages_noDuplicates() async {
        // Arrange: interleaved equal timestamps that cross a page boundary
        let server = MockServer<Row>()
        let t = ts("2025-08-26T10:00:00.123456Z")
        // Stable ascending order by (ts, id)
        let a = Row(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, updatedAtRaw: t, title: "A")
        let b = Row(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, updatedAtRaw: t, title: "B")
        let c = Row(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!, updatedAtRaw: t, title: "C")
        let d = Row(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000D")!, updatedAtRaw: t, title: "D")
        let e = Row(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000E")!, updatedAtRaw: t, title: "E")
        server.seed([a,b,c,d,e])

        let db = MockDB<Row>()
        let spec = SyncSpec<Row, Row, Row>(
            entityKey: "rows",
            pageSize: 2, // force multiple pages
            fetchSince: { ts, id, lim in server.fetchSince(ts: ts, id: id, limit: lim) },
            fetchOne: { id in server.rows.first(where: { $0.id == id }) },
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

        // Act
        let report = await SyncRunner(spec: spec).syncNow()

        // Assert
        XCTAssertEqual(report.pulled, 5)
        XCTAssertEqual(db.applied.count, 5)
        XCTAssertEqual(db.cursorTsRaw, e.updatedAtRaw) // advanced to the last row’s ts
        // We avoid asserting cursorId tie-break here since your base test covers that detail.
    }
}
