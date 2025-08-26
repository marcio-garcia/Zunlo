//
//  TaskSyncCursor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/26/25.
//

import Foundation
import RealmSwift

class SyncCursor: Object {
    @Persisted(primaryKey: true) var pk: String = ""
    @Persisted var lastTs: Date = Date(timeIntervalSince1970: 0)
    @Persisted var lastTsRaw: String?
    @Persisted var lastId: UUID?
}
