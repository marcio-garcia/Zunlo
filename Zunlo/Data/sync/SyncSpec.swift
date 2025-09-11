//
//  SyncSpec.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/26/25.
//

import Foundation

public struct SyncSpec<R: RemoteEntity, InsertPayload, UpdatePayload> {
    public let entityKey: String              // e.g. "tasks", "events"
    public let pageSize: Int                  // e.g. 500

    // API operations (supply closures)
    public let fetchSince: (_ sinceTs: String, _ sinceId: UUID?, _ pageSize: Int) async throws -> [R]
    public let fetchOne: (_ id: UUID) async throws -> R?
    public let insertReturning: (_ payloads: [InsertPayload]) async throws -> [R]
    public let updateIfVersionMatches: (_ row: R, _ payload: UpdatePayload) async throws -> R?


    // DB operations
    public let readDirty: () async throws -> [R]               // your DB returns “dirty” shaped like R (as you do today)
    public let applyPage: (_ rows: [R]) async throws -> Void   // upsert page + advance cursor atomically
    public let markClean: (_ ids: [UUID]) async throws -> Void
    public let recordConflicts: (_ items: [(R, R?)]) async throws -> Void
    public let readCursor: () async throws -> (Date, String?, UUID?)

    // Mappers
    public let isInsert: (_ r: R) -> Bool                      // e.g. { $0.version == nil }
    public let makeInsertPayload: (_ r: R) -> InsertPayload
    public let makeUpdatePayload: (_ r: R) -> UpdatePayload
}

public final class SyncRunner<R: RemoteEntity, InsertPayload, UpdatePayload> {
    private let spec: SyncSpec<R, InsertPayload, UpdatePayload>
    private let conflictCenter: ConflictResolutionCenter?
    
    public init(
        spec: SyncSpec<R, InsertPayload, UpdatePayload>,
        conflictCenter: ConflictResolutionCenter? = nil
    ) {
        self.spec = spec
        self.conflictCenter = conflictCenter
    }

    public func syncNow() async throws -> SyncReport {
        var push = PushStats.zero
        var pull = PullStats.zero
        do {
            push = try await pushDirty()
            pull = try await pullSinceCursor()
        } catch {
            // TODO: return partials; you can rethrow if you prefer
            throw error
        }
        return SyncReport.from(push: push, pull: pull)
    }

    private func pullSinceCursor() async throws -> PullStats {
        var (sinceTs, sinceTsRaw, sinceId) = try await spec.readCursor()
        var stats = PullStats.zero

        while true {
            let since = sinceTsRaw ?? RFC3339MicrosUTC.string(sinceTs)
            let rows = try await spec.fetchSince(since, sinceId, spec.pageSize)
            guard !rows.isEmpty else { break }

            try await spec.applyPage(rows)

            if let last = rows.last {
                sinceTs = last.updatedAt
                sinceTsRaw = last.updatedAtRaw
                sinceId = last.id
            }
            stats.pulled += rows.count
            stats.pages += 1
        }
        return stats
    }

    private func pushDirty() async throws -> PushStats {
        let batch = try await spec.readDirty()
        guard !batch.isEmpty else { return .zero }

        var pushedIDs: [UUID] = []
        var conflicts: [(R, R?)] = []
        var stats = PushStats.zero

        let inserts = batch.filter(spec.isInsert)
        let updates = batch.filter { !spec.isInsert($0) }

        // Bulk insert then per-item fallback
        if !inserts.isEmpty {
            do {
                let payloads = inserts.map(spec.makeInsertPayload)
                let inserted = try await spec.insertReturning(payloads)
                try await spec.applyPage(inserted)  // apply + cursor advance ok even for push
                pushedIDs += inserted.map(\.id)
                stats.inserted += inserted.count
            } catch {
                for r in inserts {
                    do {
                        let rows = try await spec.insertReturning([spec.makeInsertPayload(r)])
                        if let row = rows.first {
                            try await spec.applyPage([row])
                            pushedIDs.append(row.id)
                            stats.inserted += 1
                        }
                    } catch {
                        switch classify(error) {
                        case .conflict:
                            let server = try? await spec.fetchOne(r.id)
                            conflicts.append((r, server))
                            stats.conflicts += 1
                        case .missing:
                            stats.missing += 1
                        case .rateLimited(let ra):
                            stats.rateLimited += 1
                            await maybeBackoff(.rateLimited(retryAfter: ra))
                        case .transient:
                            stats.transientFailures += 1
                            await maybeBackoff(.transient)
                        case .permanent:
                            break
                        }
                    }
                }
            }
        }

        // Guarded updates
        for r in updates {
            do {
                let patch = spec.makeUpdatePayload(r)
                if let updated = try await spec.updateIfVersionMatches(r, patch) {
                    try await spec.applyPage([updated])
                    pushedIDs.append(updated.id)
                    stats.updated += 1
                } else {
                    let server = try? await spec.fetchOne(r.id)
                    conflicts.append((r, server))
                    stats.conflicts += 1
                }
            } catch {
                switch classify(error) {
                case .conflict:
                    let server = try? await spec.fetchOne(r.id)
                    conflicts.append((r, server))
                    stats.conflicts += 1
                case .missing:
                    stats.missing += 1
                case .rateLimited(let ra):
                    stats.rateLimited += 1
                    await maybeBackoff(.rateLimited(retryAfter: ra))
                case .transient:
                    stats.transientFailures += 1
                    await maybeBackoff(.transient)
                case .permanent:
                    break
                }
            }
        }

        try await spec.markClean(pushedIDs)

        if !conflicts.isEmpty {
            try await spec.recordConflicts(conflicts)
            // trigger auto-resolve for each conflict id
            if let center = conflictCenter {
                for (local, _) in conflicts {
                    await center.attemptAutoResolve(conflictId: "\(spec.entityKey):\(local.id.uuidString)")
                }
            }
        }

        return stats
    }
    
    // Turn any Error into a FailureKind.
    private func classify(_ error: Error) -> FailureKind {
        if let http = error as? HTTPStatusError {
            switch http.status {
            case 409, 412: return .conflict
            case 404:      return .missing
            case 408, 429: return .rateLimited(retryAfter: nil)
            case 500..<600:return .transient
            default:       return .permanent
            }
        }
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet:
                return .transient
            default:
                return .transient
            }
        }
        if error is DecodingError {
            return .permanent
        }
        return .permanent
    }

    private func maybeBackoff(_ kind: FailureKind) async {
        switch kind {
        case .rateLimited(let retryAfter):
            try? await Task.sleep(nanoseconds: UInt64((retryAfter ?? 2.0) * 1_000_000_000))
        case .transient:
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        default: break
        }
    }
}
