//
//  PayloadHelpers.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import Foundation
@testable import Zunlo

// Patch → Remote shims (TEST-ONLY). Adjust to your concrete payload shape.

extension TaskUpdatePayload {
    static func apply(patch: TaskUpdatePayload, to r: inout UserTaskRemote) {
        // Fill only the fields you use in assertions
        if let t = patch.title { r.title = t }
        if let n = patch.notes { r.notes = n }
        if let c = patch.is_completed { r.isCompleted = c }
        if let d = patch.due_date { r.dueDate = RFC3339MicrosUTC.parse(d) }
        if let p = patch.priority { r.priority = p }
        if let pid = patch.parent_event_id { r.parentEventId = pid }
        if let tags = patch.tags { r.tags = tags }
        if let trig = patch.reminder_triggers { r.reminderTriggers = trig }
        if let del = patch.deleted_at { r.deletedAt = RFC3339MicrosUTC.parse(del) }
        // Do not touch createdAt/updatedAt here (server-owned)
    }
}

extension EventUpdatePayload {
    static func apply(patch: EventUpdatePayload, to r: inout EventRemote) {
        if let t = patch.title { r.title = t }
        if let n = patch.notes { r.notes = n }
        if let l = patch.location { r.location = l }
        r.start_datetime = RFC3339MicrosUTC.parse(patch.start_datetime)!
        if let e = patch.end_datetime { r.start_datetime = RFC3339MicrosUTC.parse(e)! }
        r.is_recurring = patch.is_recurring
        if let c = patch.color { r.color = c }
        if let trig = patch.reminder_triggers { r.reminder_triggers = trig }
        if let del = patch.deleted_at { r.deletedAt = RFC3339MicrosUTC.parse(del) }
    }
}

extension RecRuleUpdatePayload {
    static func apply(patch: RecRuleUpdatePayload, to r: inout RecurrenceRuleRemote) {
        r.eventId = patch.event_id
        if let until = patch.until { r.until = until }
        if let count = patch.count { r.count = count }
        r.interval = patch.interval
        r.freq = patch.freq
        if let byweekday = patch.byweekday { r.byweekday = byweekday }
        if let bymonthday = patch.bymonthday { r.bymonthday = bymonthday }
        if let bymonth = patch.bymonth { r.bymonth = bymonth }
        if let del = patch.deleted_at { r.deletedAt = RFC3339MicrosUTC.parse(del) }
    }
}

extension EventOverrideUpdatePayload {
    static func apply(patch: EventOverrideUpdatePayload, to r: inout EventOverrideRemote) {
        r.occurrenceDate = RFC3339MicrosUTC.parse(patch.occurrence_date)!
        if let t = patch.overridden_title { r.overriddenTitle = t }
        if let n = patch.notes { r.notes = n }
        if let l = patch.overridden_location { r.overriddenLocation = l }
        if let s = patch.overridden_start_datetime { r.overriddenStartDate = RFC3339MicrosUTC.parse(s) }
        if let e = patch.overridden_end_datetime { r.overriddenEndDate = RFC3339MicrosUTC.parse(e)}
        r.eventId = patch.event_id
        r.isCancelled = patch.is_cancelled
        if let c = patch.color { r.color = c }
        if let del = patch.deletedAt { r.deletedAt = RFC3339MicrosUTC.parse(del) }
    }
}
