//
//  MoreInfoTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - More Info Tool

/// Tool for providing additional information about tasks or events
final class MoreInfoTool: ActionTool {
    private let events: EventStore
    private let tasks: TaskStore
    private let calendar: Calendar

    init(events: EventStore, tasks: TaskStore, calendar: Calendar = .appDefault) {
        self.events = events
        self.tasks = tasks
        self.calendar = calendar
    }

    // MARK: - ActionTool Conformance

    func perform(_ command: CommandContext) async -> ToolResult {
        do {
            let infoMessage = try await generateInfoMessage(for: command)

            return ToolResult(
                intent: command.intent,
                action: .info(message: infoMessage),
                needsDisambiguation: false,
                options: [],
                message: infoMessage
            )

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: "Failed to get information: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Info Generation

    private func generateInfoMessage(for command: CommandContext) async throws -> String {
        let context = command.temporalContext

        if !command.title.isEmpty {
            // User asked about a specific item - try to find it
            return try await findSpecificItemInfo(title: command.title)
        }

        // General information request
        return try await generateGeneralInfo(for: context.finalDate)
    }

    private func findSpecificItemInfo(title: String) async throws -> String {
        // Search for matching events
        let allEvents = try await events.fetchOccurrences()
        let matchingEvents = allEvents.filter { event in
            event.title.localizedCaseInsensitiveContains(title)
        }

        // Search for matching tasks
        let allTasks = try await tasks.fetchAll()
        let matchingTasks = allTasks.filter { task in
            task.title.localizedCaseInsensitiveContains(title)
        }

        if matchingEvents.isEmpty && matchingTasks.isEmpty {
            return String(format: String(localized: "I couldn't find any events or tasks matching '%@'."), title)
        }

        var infoComponents: [String] = []

        if !matchingEvents.isEmpty {
            let eventInfos = matchingEvents.prefix(3).map { event in
                formatEventInfo(event)
            }
            infoComponents.append(String(localized: "Events:\n") + eventInfos.joined(separator: "\n"))
        }

        if !matchingTasks.isEmpty {
            let taskInfos = matchingTasks.prefix(3).map { task in
                formatTaskInfo(task)
            }
            infoComponents.append(String(localized: "Tasks:\n") + taskInfos.joined(separator: "\n"))
        }

        return infoComponents.joined(separator: "\n\n")
    }

    private func generateGeneralInfo(for date: Date) async throws -> String {
        let dayRange = createDayRange(for: date)
        let weekRange = createWeekRange(for: date)

        let todayEvents = try await events.fetchOccurrences(in: dayRange)
        let weekEvents = try await events.fetchOccurrences(in: weekRange)
        let allTasks = try await tasks.fetchAll()
        let pendingTasks = allTasks.filter { !$0.isCompleted }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        let dateString = formatter.string(from: date)

        var infoComponents: [String] = []

        // Today's summary
        if todayEvents.isEmpty {
            infoComponents.append(String(localized: "No events scheduled for \(dateString)."))
        } else {
            infoComponents.append(String(localized: "Today (\(dateString)): \(todayEvents.count) event(s)"))
        }

        // Week summary
        let weekEventCount = weekEvents.count
        infoComponents.append(String(localized: "This week: \(weekEventCount) event(s)"))

        // Task summary
        if pendingTasks.isEmpty {
            infoComponents.append(String(localized: "No pending tasks"))
        } else {
            let overdueTasks = pendingTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < Date()
            }

            if overdueTasks.isEmpty {
                infoComponents.append(String(localized: "\(pendingTasks.count) pending task(s)"))
            } else {
                infoComponents.append(String(localized: "\(pendingTasks.count) pending task(s) (\(overdueTasks.count) overdue)"))
            }
        }

        return infoComponents.joined(separator: "\n")
    }

    // MARK: - Helper Methods

    private func createDayRange(for date: Date) -> Range<Date> {
        let startOfDay = date.startOfDay(calendar: calendar)
        let endOfDay = startOfDay.endOfDay(calendar: calendar)
        return startOfDay..<endOfDay
    }

    private func createWeekRange(for date: Date) -> Range<Date> {
        let startOfWeek = date.startOfWeek(calendar: calendar)
        let endOfWeek = startOfWeek.endOfWeek(calendar: calendar)
        return startOfWeek..<endOfWeek
    }

    private func formatEventInfo(_ event: EventOccurrence) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .short

        let startTime = timeFormatter.string(from: event.startDate)
        let endTime = timeFormatter.string(from: event.endDate)

        var info = "• \(event.title) - \(startTime) to \(endTime)"

        if let location = event.location, !location.isEmpty {
            info += " @ \(location)"
        }

        if let notes = event.notes, !notes.isEmpty {
            info += String(localized: "\n  Notes: \(notes)")
        }

        if event.isRecurring {
            info += String(localized: "\n  Recurring event")
        }

        return info
    }

    private func formatTaskInfo(_ task: UserTask) -> String {
        var info = "• \(task.title)"

        if let dueDate = task.dueDate {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            info += String(localized: " - Due: \(formatter.string(from: dueDate))")
        }

        if task.isCompleted {
            info += " ✓"
        }

        if let notes = task.notes, !notes.isEmpty {
            info += String(localized: "\n  Notes: \(notes)")
        }

        return info
    }
}
