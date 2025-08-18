//
//  SyncConflictLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/18/25.
//

import Foundation
import RealmSwift

final class SyncConflictLocal: Object {
    @Persisted(primaryKey: true) var id: String   // e.g. "recurrence_rules:<uuid>"
    @Persisted var table: String                  // "events" | "recurrence_rules" | "event_overrides" | "tasks"
    @Persisted var rowId: UUID
    @Persisted var localVersion: Int?
    @Persisted var remoteVersion: Int?
    @Persisted var localJSON: String
    @Persisted var remoteJSON: String?
    @Persisted var createdAt: Date
    @Persisted var resolvedAt: Date?
}
