//
//  BaseEventTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Base Event Tool

/// Base class for event-related tools with shared functionality
class BaseEventTool {
    internal let events: EventStore
    internal let calendar: Calendar
    internal let eventPicker: EnhancedEventPicker

    init(events: EventStore, calendar: Calendar = .appDefault) {
        self.events = events
        self.calendar = calendar
        self.eventPicker = EnhancedEventPicker(calendar: calendar)
    }

    // MARK: - Common Event Filtering

    /// Filter events based on temporal context and basic criteria
    func filterEventsForOperation(
        _ events: [EventOccurrence],
        command: ParseResult,
        excludeCancelled: Bool = true,
        allowPastEvents: Bool = false,
        pastEventToleranceHours: Double = 1.0,
        referenceDate: Date,
        searchWindow: DateInterval? = nil
    ) -> [EventOccurrence] {

        let now = referenceDate
        let context = command.context
        var window: DateInterval
        
        if let interval = searchWindow {
            window = interval
        } else {
            
            let startOfFinalDate = context.finalDate.startOfDay(calendar: calendar)
            var startOfNextDay = startOfFinalDate.startOfNextDay(calendar: calendar)
            startOfNextDay = calendar.date(byAdding: .second, value: -1, to: startOfNextDay) ?? startOfNextDay
            
            window = context.dateRange ?? DateInterval(
                start: startOfFinalDate,
                end: startOfNextDay
            )
        }

        return events.filter { event in
            // 1. Optionally exclude already cancelled events
            if excludeCancelled && event.isCancelled && event.deletedAt == nil {
                return false
            }

            // 2. Focus on events within reasonable time window
            let eventInWindow = window.contains(event.startDate)
            || window.contains(event.endDate)
            || (event.startDate < window.start && event.endDate > window.end)

            // 3. Optionally allow recent past events
            let isRecentPast = allowPastEvents &&
                             event.startDate > now.addingTimeInterval(-pastEventToleranceHours * 3600) &&
                             event.startDate < now

            return eventInWindow || isRecentPast
        }
    }

    // MARK: - Common Selection Handling

    func handleEventSelection(
        _ selection: CandidateSelection<EventOccurrence>,
        command: ParseResult,
        intent: Intent,
        performAction: (EventOccurrence) async -> ToolResult
    ) async -> ToolResult {

        switch selection.confidence {
        case .high:
            if let event = selection.single {
                return await performAction(event)
            }

        case .medium:
            if let event = selection.single {
                return await performAction(event)
            } else {
                return createDisambiguationResult(
                    alternatives: selection.alternatives,
                    command: command,
                    intent: intent,
                    message: createIntelligentDisambiguationMessage(selection, intent: intent)
                )
            }

        case .low, .ambiguous:
            if selection.alternatives.isEmpty {
                return createNoMatchResult(command: command, intent: intent)
            } else {
                return createDisambiguationResult(
                    alternatives: selection.alternatives,
                    command: command,
                    intent: intent,
                    message: createIntelligentDisambiguationMessage(selection, intent: intent)
                )
            }
        }

        return ToolResult(
            intent: command.intent,
            action: .info(message: "More info"),
            needsDisambiguation: true,
            options: [],
            message: "I couldn't determine which event to \(getActionVerb(for: intent)). Please be more specific.".localized
        )
    }

    // MARK: - Common Disambiguation Results

    func createDisambiguationResult(
        alternatives: [EventOccurrence],
        command: ParseResult,
        intent: Intent,
        message: String
    ) -> ToolResult {

        let options = alternatives.map { event in
            ChatMessageActionAlternative(
                id: event.id,
                parseResultId: command.id,
                intentOption: intent,
                editEventMode: nil,
                label: AttributedString(eventLabel(event))
            )
        }

        return ToolResult(
            intent: command.intent,
            action: .info(message: "Disambiguation"),
            needsDisambiguation: true,
            options: options,
            message: message
        )
    }

    func createNoMatchResult(
        command: ParseResult,
        intent: Intent
    ) -> ToolResult {

        let intelligentMessage = createNoMatchMessage(for: command, intent: intent)

        return ToolResult(
            intent: command.intent,
            action: .info(message: "No match"),
            needsDisambiguation: true,
            options: [],
            message: intelligentMessage
        )
    }

    // MARK: - Common Message Generation

    func createIntelligentDisambiguationMessage(
        _ selection: CandidateSelection<EventOccurrence>,
        intent: Intent
    ) -> String {

        let actionVerb = getActionVerb(for: intent)

        switch selection.confidence {
        case .high:
            return "I found a matching event to \(actionVerb):".localized

        case .medium:
            if selection.reasoning.scoreGap < 0.1 {
                return "I found several similar events. Which one would you like to \(actionVerb)?".localized
            } else {
                return "I found a likely match, but want to confirm which event to \(actionVerb):".localized
            }

        case .low:
            return "I found some possible matches. Which event would you like to \(actionVerb)?".localized

        case .ambiguous:
            return "I found multiple events that could match. Please choose which one to \(actionVerb):".localized
        }
    }

    func createNoMatchMessage(
        for command: ParseResult,
        intent: Intent
    ) -> String {

        let actionVerb = getActionVerb(for: intent)

        if command.title.isEmpty {
            return "Please specify which event you'd like to \(actionVerb).".localized
        } else {
            return String(format: "I couldn't find an event matching '%@' to \(actionVerb). Could you be more specific?".localized, command.title, actionVerb)
        }
    }

    private func getActionVerb(for intent: Intent) -> String {
        switch intent {
        case .cancelEvent: return "cancel"
        case .updateEvent: return "update"
        case .rescheduleEvent: return "reschedule"
        default: return "modify"
        }
    }

    // MARK: - Common Helper Methods

    func eventLabel(_ occ: EventOccurrence) -> String {
        let title = !occ.title.isEmpty ? occ.title : "(no title)".localized
        return "\(title) — \(formatTimeRange(occ.startDate, occ.endDate))"
    }

    func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func formatDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    func formatTimeRange(_ start: Date, _ end: Date) -> String {
        let df = DateIntervalFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: start, to: end)
    }

    func buildScopeOptions(
        for occ: EventOccurrence,
        parent: EventOccurrence?,
        parseResultId: UUID,
        intent: Intent,
        actionLabels: (single: String, future: String, all: String)
    ) throws -> [ChatMessageActionAlternative] {
        guard let parent = parent else {
            throw ToolError.parentNotFound
        }
        var opts: [ChatMessageActionAlternative] = []

        opts.append(ChatMessageActionAlternative(
            id: UUID(),
            parseResultId: parseResultId,
            intentOption: intent,
            editEventMode: .editSingleOccurrence(parentEvent: parent, recurrenceRule: parent.recurrence_rules.first, occurrence: occ),
            label: AttributedString(actionLabels.single)
        ))

        if occ.isRecurring {
            opts.append(ChatMessageActionAlternative(
                id: UUID(),
                parseResultId: parseResultId,
                intentOption: intent,
                editEventMode: .editFuture(parentEvent: parent, recurrenceRule: parent.recurrence_rules.first, startingFrom: occ),
                label: AttributedString(actionLabels.future)
            ))
            opts.append(ChatMessageActionAlternative(
                id: UUID(),
                parseResultId: parseResultId,
                intentOption: intent,
                editEventMode: .editAll(event: parent, recurrenceRule: parent.recurrence_rules.first),
                label: AttributedString(actionLabels.all)
            ))
        }
        return opts
    }

    func fetchParentOccurrence(for occ: EventOccurrence) async throws -> EventOccurrence? {
        if let parent = try? await events.fetchOccurrences(id: occ.eventId) { return parent }
        return nil
    }

    func buildEditInput(from occ: EventOccurrence, newStart: Date, newEnd: Date, newTitle: String? = nil, newLocation: String? = nil, newReminders: [ReminderTrigger]? = nil) -> EditEventInput {
        let rule = occ.recurrence_rules.first
        return EditEventInput(
            id: occ.id,
            userId: occ.userId,
            title: newTitle ?? occ.title,
            notes: occ.notes,
            startDate: newStart,
            endDate: newEnd,
            isRecurring: occ.isRecurring,
            location: newLocation ?? occ.location,
            color: occ.color,
            reminderTriggers: newReminders ?? occ.reminderTriggers,
            recurrenceType: rule.map { $0.freq.rawValue },
            recurrenceInterval: rule?.interval,
            byWeekday: rule?.byWeekday,
            byMonthday: rule?.byMonthday,
            until: rule?.until,
            count: rule?.count,
            isCancelled: occ.isCancelled
        )
    }
}
