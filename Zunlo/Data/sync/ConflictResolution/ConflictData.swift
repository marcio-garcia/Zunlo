//
//  ConflictData.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import Foundation

public struct ConflictData {
    public let id: String                 // "<table>:<uuid>"
    public let table: String              // "events" | "recurrence_rules" | "event_overrides" | "tasks"
    public let rowId: UUID
    public let baseVersion: Int?
    public let localVersion: Int?
    public let remoteVersion: Int?
    public let baseJSON: String?
    public let localJSON: String
    public let remoteJSON: String?
    public let createdAt: Date
    public let resolvedAt: Date?
    public let attempts: Int
    public let status: ConflictStatus
    
    init(id: String, table: String, rowId: UUID, baseVersion: Int? = nil, localVersion: Int? = nil, remoteVersion: Int? = nil, baseJSON: String? = nil, localJSON: String, remoteJSON: String? = nil, createdAt: Date, resolvedAt: Date? = nil, attempts: Int, status: ConflictStatus) {
        self.id = id
        self.table = table
        self.rowId = rowId
        self.baseVersion = baseVersion
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.baseJSON = baseJSON
        self.localJSON = localJSON
        self.remoteJSON = remoteJSON
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.attempts = attempts
        self.status = status
    }
    
    init(local: SyncConflictLocal) {
        self.id = local.id
        self.table = local.table
        self.rowId = local.rowId
        self.baseVersion = local.baseVersion
        self.localVersion = local.localVersion
        self.remoteVersion = local.remoteVersion
        self.baseJSON = local.baseJSON
        self.localJSON = local.localJSON
        self.remoteJSON = local.remoteJSON
        self.createdAt = local.createdAt
        self.resolvedAt = local.resolvedAt
        self.attempts = local.attempts
        self.status = ConflictStatus(rawValue: local.statusRaw)!
    }
}
