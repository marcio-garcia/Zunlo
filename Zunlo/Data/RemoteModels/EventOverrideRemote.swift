//
//  EventOverrideRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

extension EventOverrideRemote {
    var isInsertCandidate: Bool { version == nil }
}

public struct EventOverrideRemote: RemoteEntity, Codable, Identifiable {
    public var id: UUID
    public var eventId: UUID
    public var occurrenceDate: Date
    public var overriddenTitle: String?
    public var overriddenStartDate: Date?
    public var overriddenEndDate: Date?
    public var overriddenLocation: String?
    public var isCancelled: Bool
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedAtRaw: String?
    public var color: EventColor?
    public var deletedAt: Date?
    public var version: Int?
}

extension EventOverrideRemote {
    init(domain: EventOverride) {
        self.id = domain.id
        self.eventId = domain.eventId
        self.occurrenceDate = domain.occurrenceDate
        self.overriddenTitle = domain.overriddenTitle
        self.overriddenStartDate = domain.overriddenStartDate
        self.overriddenEndDate = domain.overriddenEndDate
        self.overriddenLocation = domain.overriddenLocation
        self.isCancelled = domain.isCancelled
        self.notes = domain.notes
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.color = domain.color
        self.deletedAt = domain.deletedAt
        self.version = domain.version
    }
    
    init(local: EventOverrideLocal) {
        self.id = local.id
        self.eventId = local.eventId
        self.occurrenceDate = local.occurrenceDate
        self.overriddenTitle = local.overriddenTitle
        self.overriddenStartDate = local.overriddenStartDate
        self.overriddenEndDate = local.overriddenEndDate
        self.overriddenLocation = local.overriddenLocation
        self.isCancelled = local.isCancelled
        self.notes = local.notes
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
        self.color = local.color
        self.deletedAt = local.deletedAt
        self.version = local.version
    }
}

extension EventOverrideRemote {
    enum CodingKeys: String, CodingKey {
        case id
        case eventId                = "event_id"
        case occurrenceDate         = "occurrence_date"
        case overriddenTitle        = "overridden_title"
        case overriddenStartDate    = "overridden_start_datetime"
        case overriddenEndDate      = "overridden_end_datetime"
        case overriddenLocation     = "overridden_location"
        case isCancelled            = "is_cancelled"
        case notes
        case color
        case createdAt              = "created_at"   // REQUIRED from server; we DO NOT encode it
        case updatedAt              = "updated_at"   // REQUIRED
        case deletedAt              = "deleted_at"
        case version
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(UUID.self, forKey: .id)
        eventId = try c.decode(UUID.self, forKey: .eventId)
        overriddenTitle = try c.decodeIfPresent(String.self, forKey: .overriddenTitle)
        overriddenLocation = try c.decodeIfPresent(String.self, forKey: .overriddenLocation)
        isCancelled = try c.decode(Bool.self, forKey: .isCancelled)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        color = try c.decodeIfPresent(EventColor.self, forKey: .color)
        version = try c.decodeIfPresent(Int.self, forKey: .version)
        
        occurrenceDate = Date()
        let dateRaw = try c.decode(String.self, forKey: .occurrenceDate)
        if let dateParsed = RFC3339MicrosUTC.parse(dateRaw) {
            occurrenceDate = dateParsed
        }
        
        if let dateRaw = try c.decodeIfPresent(String.self, forKey: .overriddenStartDate),
           let dateParsed = RFC3339MicrosUTC.parse(dateRaw) {
            overriddenStartDate = dateParsed
        } else {
            overriddenStartDate = nil
        }
        if let dateRaw = try c.decodeIfPresent(String.self, forKey: .overriddenEndDate),
           let dateParsed = RFC3339MicrosUTC.parse(dateRaw) {
            overriddenEndDate = dateParsed
        } else {
            overriddenEndDate = nil
        }
        
        // Decode updatedAt (required) first so we can use it as a fallback for createdAt during migration.
        let raw = try c.decode(String.self, forKey: .updatedAt)
        updatedAtRaw = raw
        guard let updatedAtParsed = RFC3339MicrosUTC.parse(raw) else {
            _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "updated_at", raw: raw)
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: c, debugDescription: "Invalid updated_at: \(raw)")
        }
        updatedAt = updatedAtParsed

        // createdAt is REQUIRED (server wins entirely). Use tolerant parse; allow temporary fallback if enabled.
        let createdAtRaw = try c.decode(String.self, forKey: .createdAt)
        if let createdAtParsed = RFC3339MicrosUTC.parse(createdAtRaw) {
            createdAt = createdAtParsed
        } else if _DecodePolicy.allowCreatedAtFallbackDuringMigration {
            _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "created_at", raw: createdAtRaw)
            // Mitigation C: temporary unblock—use updatedAt. Remove once DB is clean.
            createdAt = updatedAt
        } else {
            _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "created_at", raw: createdAtRaw)
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: c, debugDescription: "Invalid created_at: \(createdAtRaw)")
        }

        if let delRaw = try c.decodeIfPresent(String.self, forKey: .deletedAt) {
            guard let d = RFC3339MicrosUTC.parse(delRaw) else {
                _DecodePolicy.reportDecodeIssue(entity: "UserTaskRemote", id: id, field: "deleted_at", raw: delRaw)
                throw DecodingError.dataCorruptedError(forKey: .deletedAt, in: c, debugDescription: "Invalid deleted_at: \(delRaw)")
            }
            deletedAt = d
        } else {
            deletedAt = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        let strategy = (encoder.userInfo[.serverOwnedEncodingStrategy] as? ServerOwnedEncoding) ?? .exclude
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(id, forKey: .id)
        try c.encode(eventId, forKey: .eventId)
        try c.encodeIfPresent(overriddenTitle, forKey: .overriddenTitle)
        try c.encodeIfPresent(overriddenLocation, forKey: .overriddenLocation)
        try c.encode(isCancelled, forKey: .isCancelled)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(color, forKey: .color)
        try c.encode(RFC3339MicrosUTC.string(occurrenceDate), forKey: .occurrenceDate)
        try c.encodeIfPresent(overriddenStartDate.map(RFC3339MicrosUTC.string), forKey: .overriddenStartDate)
        try c.encodeIfPresent(overriddenEndDate.map(RFC3339MicrosUTC.string), forKey: .overriddenEndDate)
        
        try c.encodeIfPresent(deletedAt.map(RFC3339MicrosUTC.string), forKey: .deletedAt)
        try c.encodeIfPresent(version, forKey: .version)
                
        // Do NOT encode created_at nor updated_at
        // when sending to server — server owns it
        switch strategy {
        case .include:
            try c.encode(RFC3339MicrosUTC.string(updatedAt), forKey: .updatedAt)
            try c.encode(RFC3339MicrosUTC.string(createdAt), forKey: .createdAt)
        case .exclude:
            break
        }
    }
}
