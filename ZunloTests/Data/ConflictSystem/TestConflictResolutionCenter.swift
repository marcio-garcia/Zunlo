//
//  TestConflictResolutionCenter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import Foundation
@testable import Zunlo

// The center fetches the snapshot via your DB façade, increments attempts, dispatches to the correct resolver.
// The resolver performs 3-way merge with your table-specific invariants.
// The API call is guarded (expected version) and on success the DB is updated and the conflict is marked autoResolved.
// On nil return (version mismatch) it marks needsUser; on thrown 409/5xx it fails (you can change to needsUser if you prefer).
// If you prefer 409 to become needsUser rather than failed, update your resolver’s catch to call setConflictNeedsUser for HTTPStatusError(status: 409/412, …) and keep the tests in lockstep.

// MARK: - Conflict center that uses MockDatabaseActor

final class TestConflictResolutionCenter {
    private let db: ConflictDB
    private let resolvers: [String: AnyConflictResolver]

    init(db: ConflictDB, resolvers: [AnyConflictResolver]) {
        self.db = db
        self.resolvers = Dictionary(uniqueKeysWithValues: resolvers.map { ($0.table, $0) })
    }

    func attemptAutoResolve(conflictId: String) async {
        guard let snapshot = try? await db.fetchPendingConflict(conflictId) else { return }
        guard let resolver = resolvers[snapshot.table] else { return }
        try? await db.bumpConflictAttempt(conflictId)
        await resolver.attemptAutoResolve(conflict: snapshot, db: db)
    }
}

// MARK: - JSON helpers (mirror your production ones)

extension JSONEncoder {
    static func supabaseMicros() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601 // good enough for tests; your app uses 6-fraction
        return enc
    }
}
extension JSONDecoder {
    static func supabaseMicroFirst() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }
}

//@inline(__always) func encodeJSON<T: Encodable>(_ v: T) -> String {
//    let d = try! JSONEncoder.supabaseMicros().encode(v)
//    return String(data: d, encoding: .utf8)!
//}
