//
//  RecRuleOpPayload.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/27/25.
//

import Foundation

// MARK: - Task payloads (server owns created_at/updated_at)
public struct RecRuleInsertPayload: Encodable {
    let id: UUID
    let event_id: UUID
    let freq: String
    let interval: Int
    let byweekday: [Int]?
    let bymonthday: [Int]?
    let bymonth: [Int]?
    let until: Date?
    let count: Int?
    let deleted_at: String?
    
    init(remote r: RecurrenceRuleRemote) {
        id = r.id
        event_id = r.eventId
        freq = r.freq
        interval = r.interval
        byweekday = r.byweekday
        bymonthday = r.bymonthday
        bymonth = r.bymonth
        until = r.until
        count = r.count
        deleted_at = r.deletedAt.map(RFC3339MicrosUTC.string)
    }
}

public struct RecRuleUpdatePayload: Encodable {
    // PATCH-style optionals (send all for now = minimal change; you can sparsify later)
    let event_id: UUID
    let freq: String
    let interval: Int
    let byweekday: [Int]?
    let bymonthday: [Int]?
    let bymonth: [Int]?
    let until: Date?
    let count: Int?
    let deleted_at: String?
    
    static func full(from r: RecurrenceRuleRemote) -> RecRuleUpdatePayload {
        .init(
            event_id: r.eventId,
            freq: r.freq,
            interval: r.interval,
            byweekday: r.byweekday,
            bymonthday: r.bymonthday,
            bymonth: r.bymonth,
            until: r.until,
            count: r.count,
            deleted_at: r.deletedAt.map(RFC3339MicrosUTC.string)
        )
    }
}
