//
//  EventOccurrenceRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/10/25.
//

import Foundation

struct EventOccurrenceResponse: Codable, Identifiable {
    let id: UUID
    let user_id: UUID
    let title: String
    let notes: String?
    let start_datetime: Date
    let end_datetime: Date?
    let is_recurring: Bool
    let location: String?
    let created_at: Date
    let updated_at: Date
    let color: String?
    let reminderTriggers: [ReminderTrigger]?
    let overrides: [EventOverrideRemote]
    let recurrence_rules: [RecurrenceRuleRemote]
    let deletedAt: Date?
    let needsSync: Bool
}

extension EventOccurrenceResponse {
    init(local e: EventLocal,
         overrides ovs: [EventOverrideLocal],
         rules rrs: [RecurrenceRuleLocal]) {

        self.id = e.id
        self.user_id = e.userId ?? UUID()
        self.title = e.title
        self.notes = e.notes
        self.start_datetime = e.startDate
        self.end_datetime = e.endDate
        self.is_recurring = e.isRecurring
        self.location = (e.location ?? "") + (e.deletedAt?.description ?? "")
        self.created_at = e.createdAt
        self.updated_at = e.updatedAt
        self.color = e.color?.rawValue
        self.reminderTriggers = e.reminderTriggersArray
        self.deletedAt = e.deletedAt
        self.needsSync = e.needsSync

        // Map children → Remote DTOs; keep deterministic order by id to match SQL
        self.overrides = ovs
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { EventOverrideRemote(local: $0) }

        self.recurrence_rules = rrs
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { RecurrenceRuleRemote(local: $0) }
    }
}
