//
//  EventOccurrenceService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

enum EventOccurrenceError: Error {
    case overrideIDIsNil
    case eventIDIsNill
}

struct EventOccurrenceService {
    
    /// Generate all event occurrences (including overrides/cancellations) in the given range.
    static func generate(rawOccurrences: [EventOccurrence],
                         in range: ClosedRange<Date>) throws -> [EventOccurrence] {
        var occurrences: [EventOccurrence] = []

        for rawOcc in rawOccurrences {
            if rawOcc.isRecurring {
                // Recurring event
                let ruleDict = Dictionary(grouping: rawOcc.recurrence_rules, by: { $0.eventId })
                let overrideDict = Dictionary(grouping: rawOcc.overrides, by: { $0.eventId })
                
                guard let rule = ruleDict[rawOcc.eventId]?.first else { continue }
                
                let dates = RecurrenceHelper.generateRecurrenceDates(
                    start: rawOcc.startDate,
                    rule: rule,
                    within: range
                )
                                
                let eventOverrides = overrideDict[rawOcc.eventId] ?? []

                for date in dates {
                    // Is there an override/cancellation?
                    if let ov = eventOverrides.first(where: { $0.occurrenceDate.isSameDay(as: date) }) {
                        if ov.isCancelled { continue }
                        guard let overrideId = ov.id else { throw EventOccurrenceError.overrideIDIsNil }
                        let occu = EventOccurrence(
                            id: overrideId,
                            userId: rawOcc.userId,
                            eventId: ov.eventId,
                            title: ov.overriddenTitle ?? rawOcc.title,
                            description: rawOcc.description,
                            startDate: ov.overriddenStartDate ?? date,
                            endDate: ov.overriddenEndDate ?? rawOcc.endDate,
                            isRecurring: rawOcc.isRecurring,
                            location: ov.overriddenLocation ?? rawOcc.location,
                            color: ov.color,
                            isOverride: true,
                            isCancelled: false,
                            updatedAt: ov.updatedAt,
                            createdAt: ov.createdAt,
                            overrides: eventOverrides,
                            recurrence_rules: [rule]
                        )
                        occurrences.append(occu)
                    } else {
                        let eventDuration = rawOcc.endDate?.timeIntervalSince(rawOcc.startDate)
                        let occu = EventOccurrence(
                            id: date == rawOcc.startDate ? rawOcc.id : UUID(),
                            userId: rawOcc.userId,
                            eventId: rawOcc.eventId,
                            title: rawOcc.title,
                            description: rawOcc.description,
                            startDate: date,
                            endDate: eventDuration == nil ? nil : date.addingTimeInterval(eventDuration ?? 0),
                            isRecurring: rawOcc.isRecurring,
                            location: rawOcc.location,
                            color: rawOcc.color,
                            isOverride: false,
                            isCancelled: false,
                            updatedAt: rawOcc.updatedAt,
                            createdAt: rawOcc.createdAt,
                            overrides: eventOverrides,
                            recurrence_rules: [rule]
                        )
                        occurrences.append(occu)
                    }
                }
            } else {
                // Regular event
                guard range.contains(rawOcc.startDate) else { continue }
                let isCancelled = rawOcc.overrides.contains(where: { $0.eventId == rawOcc.eventId && $0.occurrenceDate == rawOcc.startDate && $0.isCancelled })
                if !isCancelled {
                    // If there's an override for this one-off event, apply it
                    if let ov = rawOcc.overrides.first(where: { $0.eventId == rawOcc.eventId && $0.occurrenceDate == rawOcc.startDate }) {
                        guard let overrideId = ov.id else { throw EventOccurrenceError.overrideIDIsNil }
                        let occu = EventOccurrence(
                            id: overrideId,
                            userId: rawOcc.userId,
                            eventId: ov.eventId,
                            title: ov.overriddenTitle ?? rawOcc.title,
                            description: rawOcc.description,
                            startDate: ov.overriddenStartDate ?? rawOcc.startDate,
                            endDate: ov.overriddenEndDate ?? rawOcc.endDate,
                            isRecurring: rawOcc.isRecurring,
                            location: ov.overriddenLocation ?? rawOcc.location,
                            color: ov.color,
                            isOverride: true,
                            isCancelled: false,
                            updatedAt: ov.updatedAt,
                            createdAt: ov.createdAt,
                            overrides: [],
                            recurrence_rules: []
                        )
                        occurrences.append(occu)
                    } else {
                        let occu = EventOccurrence(
                            id: rawOcc.eventId,
                            userId: rawOcc.userId,
                            eventId: rawOcc.eventId,
                            title: rawOcc.title,
                            description: rawOcc.description,
                            startDate: rawOcc.startDate,
                            endDate: rawOcc.endDate,
                            isRecurring: rawOcc.isRecurring,
                            location: rawOcc.location,
                            color: rawOcc.color,
                            isOverride: false,
                            isCancelled: false,
                            updatedAt: rawOcc.updatedAt,
                            createdAt: rawOcc.createdAt,
                            overrides: [],
                            recurrence_rules: []
                        )
                        occurrences.append(occu)
                    }
                }
            }
        }

        let occ = RecurrenceHelper.addTodayIfNeeded(occurrences: occurrences)
        return occ.sorted { $0.startDate < $1.startDate }
    }
}
