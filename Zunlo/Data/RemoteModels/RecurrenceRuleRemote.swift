//
//  RecurrenceRuleRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

extension RecurrenceRuleRemote {
    var isInsertCandidate: Bool { version == nil }
}

public struct RecurrenceRuleRemote: RemoteEntity, Codable, Identifiable {
    public var id: UUID
    public var eventId: UUID
    public var freq: String
    public var interval: Int
    public var byweekday: [Int]?
    public var bymonthday: [Int]?
    public var bymonth: [Int]?
    public var until: Date?
    public var count: Int?
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedAtRaw: String?
    public var deletedAt: Date? = nil
    public var version: Int?
}

extension RecurrenceRuleRemote {
    internal init(local: RecurrenceRuleLocal) {
        self.id = local.id
        self.eventId = local.eventId
        self.freq = local.freq
        self.interval = local.interval
        self.byweekday = local.byWeekdayArray
        self.bymonthday = local.byMonthdayArray
        self.bymonth = local.byMonthArray
        self.until = local.until
        self.count = local.count
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
        self.deletedAt = local.deletedAt
        self.version = local.version
    }
    
    init(domain: RecurrenceRule) {
        self.id = domain.id
        self.eventId = domain.eventId
        self.freq = domain.freq.rawValue
        self.interval = domain.interval
        self.byweekday = domain.byWeekday
        self.bymonthday = domain.byMonthday
        self.bymonth = domain.byMonth
        self.until = domain.until
        self.count = domain.count
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
        self.deletedAt = domain.deletedAt
        self.version = domain.version
    }
}

extension RecurrenceRuleRemote {
    enum CodingKeys: String, CodingKey {
        case id
        case eventId            = "event_id"
        case freq
        case interval
        case byweekday
        case bymonthday
        case bymonth
        case until
        case count
        case createdAt          = "created_at"   // REQUIRED from server; we DO NOT encode it
        case updatedAt          = "updated_at"   // REQUIRED
        case deletedAt          = "deleted_at"
        case version
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(UUID.self, forKey: .id)
        eventId = try c.decode(UUID.self, forKey: .eventId)
        freq = try c.decode(String.self, forKey: .freq)
        interval = try c.decode(Int.self, forKey: .interval)
        byweekday = try c.decodeIfPresent([Int].self, forKey: .byweekday)
        bymonthday = try c.decodeIfPresent([Int].self, forKey: .bymonthday)
        bymonth = try c.decodeIfPresent([Int].self, forKey: .bymonth)
        count = try c.decodeIfPresent(Int.self, forKey: .count)
        version = try c.decodeIfPresent(Int.self, forKey: .version)

        if let untilRaw = try c.decodeIfPresent(String.self, forKey: .until),
           let untilParsed = RFC3339MicrosUTC.parse(untilRaw) {
            until = untilParsed
        } else {
            until = nil
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
        try c.encode(freq, forKey: .freq)
        try c.encode(interval, forKey: .interval)
        try c.encodeIfPresent(byweekday, forKey: .byweekday)
        try c.encodeIfPresent(bymonthday, forKey: .bymonthday)
        try c.encodeIfPresent(bymonth, forKey: .bymonth)
        try c.encodeIfPresent(until, forKey: .until)
        try c.encodeIfPresent(count, forKey: .count)
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
