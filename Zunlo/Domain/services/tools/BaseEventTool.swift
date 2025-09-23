//
//  BaseEventTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SwiftUI
import SmartParseKit
import GlowUI

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
    func filterEventsByDate(
        _ events: [EventOccurrence],
        context: CommandContext,
        excludeCancelled: Bool = true,
        allowPastEvents: Bool = false,
        pastEventToleranceHours: Double = 1.0,
        referenceDate: Date,
        searchWindow: DateInterval? = nil
    ) -> [EventOccurrence] {

        let now = referenceDate
        let temporalContext = context.temporalContext
        var window: DateInterval

        if let interval = searchWindow {
            window = interval
        } else {

            let startOfFinalDate = temporalContext.finalDate.startOfDay(calendar: calendar)
            var startOfNextDay = startOfFinalDate.startOfNextDay(calendar: calendar)
            startOfNextDay = calendar.date(byAdding: .second, value: -1, to: startOfNextDay) ?? startOfNextDay

            window = temporalContext.dateRange ?? DateInterval(
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
        context: CommandContext,
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
                    context: context,
                    intent: intent,
                    message: createIntelligentDisambiguationMessage(selection, intent: intent)
                )
            }

        case .low, .ambiguous:
            if selection.alternatives.isEmpty {
                return createNoMatchResult(context: context, intent: intent)
            } else {
                return createDisambiguationResult(
                    alternatives: selection.alternatives,
                    context: context,
                    intent: intent,
                    message: createIntelligentDisambiguationMessage(selection, intent: intent)
                )
            }
        }

        return ToolResult(
            intent: context.intent,
            action: .info(message: "More info"),
            needsDisambiguation: true,
            options: [],
            message: "I couldn't determine which event to \(getActionVerb(for: intent)). Please be more specific.".localized
        )
    }

    // MARK: - Common Disambiguation Results

    func createDisambiguationResult(
        alternatives: [EventOccurrence],
        context: CommandContext,
        intent: Intent,
        message: String
    ) -> ToolResult {

        let options = alternatives.map { event in
            ChatMessageActionAlternative(
                id: UUID(),  // Generate new UUID for disambiguation choice
                commandContextId: context.id,
                intentOption: intent,
                editEventMode: nil,
                label: eventLabel(event),
                eventOccurrence: event  // Store the full occurrence
            )
        }

        return ToolResult(
            intent: context.intent,
            action: .info(message: "Disambiguation"),
            needsDisambiguation: true,
            options: options,
            message: message
        )
    }

    func createNoMatchResult(
        context: CommandContext,
        intent: Intent
    ) -> ToolResult {

        let intelligentMessage = createNoMatchMessage(for: context, intent: intent)

        return ToolResult(
            intent: context.intent,
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
        for context: CommandContext,
        intent: Intent
    ) -> String {

        let actionVerb = getActionVerb(for: intent)

        if context.title.isEmpty {
            return "Please specify which event you'd like to \(actionVerb).".localized
        } else {
            return String(format: "I couldn't find an event matching '%@' to \(actionVerb). Could you be more specific?".localized, context.title, actionVerb)
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

    func eventLabel(_ occ: EventOccurrence) -> AttributedString {
        var attributedLabel = AttributedString()

        // Event title (bold, primary text color)
        let title = !occ.title.isEmpty ? occ.title : "(no title)".localized
        var titleText = AttributedString(title)
        titleText.font = AppFontStyle.body.weight(.bold).uiFont()
        titleText.foregroundColor = UIColor(Color.theme.text)
        attributedLabel += titleText

        // Separator
        var separator = AttributedString(" — ")
        separator.font = AppFontStyle.body.weight(.semibold).uiFont()
        separator.foregroundColor = UIColor(Color.theme.secondaryText)
        attributedLabel += separator

        // Date (medium weight, secondary text color)
        var dateText = AttributedString(formatDay(occ.startDate))
        dateText.font = AppFontStyle.body.weight(.medium).uiFont()
        dateText.foregroundColor = UIColor(Color.theme.secondaryText)
        attributedLabel += dateText

        // Time range (caption, secondary text color)
        var timeText = AttributedString(" \(formatTimeRange(occ.startDate, occ.endDate))")
        timeText.font = AppFontStyle.caption.uiFont()
        timeText.foregroundColor = UIColor(Color.theme.secondaryText)
        attributedLabel += timeText

        return attributedLabel
    }
    
    func scopeLabel(_ text: String) -> AttributedString {
        var attributedLabel = AttributedString()

        // Event title (bold, primary text color)
        let title = !text.isEmpty ? text : "(no title)".localized
        var titleText = AttributedString(title)
        titleText.font = AppFontStyle.body.weight(.bold).uiFont()
        titleText.foregroundColor = UIColor(Color.theme.text)
        attributedLabel += titleText

        return attributedLabel
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
        commandContextId: UUID,
        intent: Intent,
        actionLabels: (single: String, future: String, all: String)
    ) throws -> [ChatMessageActionAlternative] {
        guard let parent = parent else {
            throw ToolError.parentNotFound
        }
        var opts: [ChatMessageActionAlternative] = []

        opts.append(ChatMessageActionAlternative(
            id: UUID(),
            commandContextId: commandContextId,
            intentOption: intent,
            editEventMode: .editSingleOccurrence(parentEvent: parent, recurrenceRule: parent.recurrence_rules.first, occurrence: occ),
            label: scopeLabel(actionLabels.single),
            eventOccurrence: occ
        ))

        if occ.isRecurring {
            opts.append(ChatMessageActionAlternative(
                id: UUID(),
                commandContextId: commandContextId,
                intentOption: intent,
                editEventMode: .editFuture(parentEvent: parent, recurrenceRule: parent.recurrence_rules.first, startingFrom: occ),
                label: scopeLabel(actionLabels.future),
                eventOccurrence: occ
            ))
            opts.append(ChatMessageActionAlternative(
                id: UUID(),
                commandContextId: commandContextId,
                intentOption: intent,
                editEventMode: .editAll(event: parent, recurrenceRule: parent.recurrence_rules.first),
                label: scopeLabel(actionLabels.all),
                eventOccurrence: parent  // Use parent for "all" scope
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

    // MARK: - Generic Event Edit Operations

    /// Generic method to execute edit mode operations on recurring events
    func executeEditMode(
        _ editMode: AddEditEventViewMode,
        with editInput: EditEventInput,
        operationName: String
    ) async throws {
        switch editMode {
        case .editAll(let event, let recurrenceRule):
            try await events.editAll(event: event, with: editInput, oldRule: recurrenceRule)
        case .editSingleOccurrence(let parentEvent, _, let occurrence):
            try await events.editSingleOccurrence(parent: parentEvent, occurrence: occurrence, with: editInput)
        case .editOverride(let override):
            try await events.editOverride(override, with: editInput)
        case .editFuture(let parentEvent, _, let startingFrom):
            try await events.editFuture(parent: parentEvent, startingFrom: startingFrom, with: editInput)
        default:
            throw ToolError.unsupportedEditMode(operationName)
        }
    }

    /// Generic method to create scope disambiguation result
    func createGenericScopeDisambiguationResult(
        for event: EventOccurrence,
        parent: EventOccurrence?,
        command: CommandContext,
        actionLabels: (single: String, future: String, all: String),
        disambiguationMessage: String
    ) throws -> ToolResult {
        let opts = try buildScopeOptions(
            for: event,
            parent: parent,
            commandContextId: command.id,
            intent: command.intent,
            actionLabels: actionLabels
        )

        return ToolResult(
            intent: command.intent,
            action: .targetEventOccurrence(eventId: event.id, start: event.startDate),
            needsDisambiguation: true,
            options: opts,
            message: disambiguationMessage
        )
    }

    /// Generic method to handle recurring event operations
    func handleRecurringEventOperation(
        _ event: EventOccurrence,
        command: CommandContext,
        actionLabels: (single: String, future: String, all: String),
        disambiguationMessage: String,
        operationName: String,
        editInputBuilder: () -> EditEventInput,
        successResultBuilder: () -> ToolResult
    ) async -> ToolResult {
        do {
            let parent = try await fetchParentOccurrence(for: event)

            if let editMode = command.editEventMode {
                let editInput = editInputBuilder()
                try await executeEditMode(editMode, with: editInput, operationName: operationName)
                return successResultBuilder()
            } else {
                return try createGenericScopeDisambiguationResult(
                    for: event,
                    parent: parent,
                    command: command,
                    actionLabels: actionLabels,
                    disambiguationMessage: disambiguationMessage
                )
            }
        } catch {
            return ToolResult(
                intent: command.intent,
                action: .info(message: "Error"),
                needsDisambiguation: false,
                options: [],
                message: "Failed to \(operationName.lowercased()) recurring event: \(error.localizedDescription)"
            )
        }
    }

    /// Generic method to handle single event operations
    func handleSingleEventOperation(
        _ event: EventOccurrence,
        command: CommandContext,
        operationName: String,
        editInputBuilder: () -> EditEventInput,
        successResultBuilder: () -> ToolResult
    ) async -> ToolResult {
        do {
            let editInput = editInputBuilder()
            try await events.editAll(event: event, with: editInput, oldRule: nil)
            return successResultBuilder()
        } catch {
            return ToolResult(
                intent: command.intent,
                action: .info(message: "Error"),
                needsDisambiguation: false,
                options: [],
                message: "Failed to \(operationName.lowercased()) single event: \(error.localizedDescription)"
            )
        }
    }
}
