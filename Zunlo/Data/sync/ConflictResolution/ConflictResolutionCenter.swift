//
//  ConflictResolutionCenter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

// Keep it simple: each resolver knows how to decode/merge/apply for one table.
public protocol AnyConflictResolver {
    var table: String { get }
    func attemptAutoResolve(conflict: ConflictData, db: ConflictDB) async
}

public final class ConflictResolutionCenter {
    private let db: ConflictDB
    private let resolvers: [String: AnyConflictResolver]

    init(db: ConflictDB, resolvers: [AnyConflictResolver]) {
        self.db = db
        self.resolvers = Dictionary(uniqueKeysWithValues: resolvers.map { ($0.table, $0) })
    }

    func attemptAutoResolve(conflictId: String) async {
        do {
            guard let snapshot = try await db.fetchPendingConflict(conflictId) else { return }
            guard let resolver = resolvers[snapshot.table] else { return }
            try await db.bumpConflictAttempt(conflictId)
            await resolver.attemptAutoResolve(conflict: snapshot, db: db)
        } catch {
            // swallow / telemetry hook
        }
    }
}
