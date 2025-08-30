//
//  SyncConflictLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation
import RealmSwift

public final class SyncConflictLocal: Object {
    @Persisted(primaryKey: true) var id: String   // e.g. "tasks:<uuid>"
    @Persisted var table: String                  // "events" | "recurrence_rules" | "event_overrides" | "tasks"
    @Persisted var rowId: UUID

    @Persisted var baseVersion: Int?              // remote version when local edit started
    @Persisted var localVersion: Int?
    @Persisted var remoteVersion: Int?

    @Persisted var baseJSON: String?              // remote snapshot when local edit started
    @Persisted var localJSON: String              // current local state at conflict time
    @Persisted var remoteJSON: String?            // current server state at conflict time

    @Persisted var createdAt: Date
    @Persisted var resolvedAt: Date?

    // NEW: resolution lifecycle
    @Persisted var statusRaw: String = ConflictStatus.pending.rawValue
    @Persisted var resolutionRaw: String?         // "autoMerged" | "keepLocal" | "keepServer"
    @Persisted var attempts: Int = 0
    @Persisted var lastError: String?

    // Optional: UX/telemetry
    @Persisted var localEditedAt: Date?           // when user edited locally (for “newer wins”)
}

public enum ConflictStatus: String {
    case pending, autoResolved, needsUser, failed, resolved
}
public enum ResolutionStrategy: String {
    case autoMerged, keepLocal, keepServer
}

