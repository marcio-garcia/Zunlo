//
//  ToolCoordinator.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Tool Coordinator

protocol Tools {
    func createTask(_ context: CommandContext) async -> ToolResult
    func createEvent(_ context: CommandContext) async -> ToolResult
    func rescheduleTask(_ context: CommandContext) async -> ToolResult
    func rescheduleEvent(_ context: CommandContext) async -> ToolResult
    func updateTask(_ context: CommandContext) async -> ToolResult
    func updateEvent(_ context: CommandContext) async -> ToolResult
    func cancelTask(_ context: CommandContext) async -> ToolResult
    func cancelEvent(_ context: CommandContext) async -> ToolResult
    func planWeek(_ context: CommandContext) async -> ToolResult
    func planDay(_ context: CommandContext) async -> ToolResult
    func showAgenda(_ context: CommandContext) async -> ToolResult
    func moreInfo(_ context: CommandContext) async -> ToolResult
    func unknown(_ context: CommandContext) async -> ToolResult
}

/// Coordinator that manages individual ActionTool instances and routes commands to the appropriate tool
final class ToolCoordinator: Tools {
    private let events: EventStore
    private let tasks: TaskStore
    private let calendar: Calendar

    // Individual tools
    private let cancelEventTool: CancelEventTool
    private let rescheduleEventTool: RescheduleEventTool
    private let updateEventTool: UpdateEventTool
    private let createEventTool: CreateEventTool
    private let createTaskTool: CreateTaskTool
    private let updateTaskTool: UpdateTaskTool
    private let cancelTaskTool: CancelTaskTool
    private let rescheduleTaskTool: RescheduleTaskTool
    private let planDayTool: PlanDayTool
    private let planWeekTool: PlanWeekTool
    private let showAgendaTool: ShowAgendaTool
    private let moreInfoTool: MoreInfoTool
    private let unknownTool: UnknownTool

    init(events: EventStore, tasks: TaskStore, userId: UUID, referenceDate: Date, calendar: Calendar = .appDefault) {
        self.events = events
        self.tasks = tasks
        self.calendar = calendar

        // Initialize all tools
        self.cancelEventTool = CancelEventTool(events: events, referenceDate: referenceDate, calendar: calendar)
        self.rescheduleEventTool = RescheduleEventTool(events: events, referenceDate: referenceDate, calendar: calendar)
        self.updateEventTool = UpdateEventTool(events: events, referenceDate: referenceDate, calendar: calendar)
        self.createEventTool = CreateEventTool(events: events, userId: userId, calendar: calendar)
        self.createTaskTool = CreateTaskTool(tasks: tasks, userId: userId, referenceDate: referenceDate, calendar: calendar)
        self.updateTaskTool = UpdateTaskTool(tasks: tasks, referenceDate: referenceDate, calendar: calendar)
        self.cancelTaskTool = CancelTaskTool(tasks: tasks, referenceDate: referenceDate, calendar: calendar)
        self.rescheduleTaskTool = RescheduleTaskTool(tasks: tasks, referenceDate: referenceDate, calendar: calendar)
        self.planDayTool = PlanDayTool(events: events, calendar: calendar)
        self.planWeekTool = PlanWeekTool(events: events, calendar: calendar)
        self.showAgendaTool = ShowAgendaTool(events: events, calendar: calendar)
        self.moreInfoTool = MoreInfoTool(events: events, tasks: tasks, calendar: calendar)
        self.unknownTool = UnknownTool()
    }

    // MARK: - Tools Protocol Conformance

    func createTask(_ context: CommandContext) async -> ToolResult {
        return await createTaskTool.perform(context)
    }

    func createEvent(_ context: CommandContext) async -> ToolResult {
        return await createEventTool.perform(context)
    }

    func rescheduleTask(_ context: CommandContext) async -> ToolResult {
        return await rescheduleTaskTool.perform(context)
    }

    func rescheduleEvent(_ context: CommandContext) async -> ToolResult {
        return await rescheduleEventTool.perform(context)
    }

    func updateTask(_ context: CommandContext) async -> ToolResult {
        return await updateTaskTool.perform(context)
    }

    func updateEvent(_ context: CommandContext) async -> ToolResult {
        return await updateEventTool.perform(context)
    }

    func cancelTask(_ context: CommandContext) async -> ToolResult {
        return await cancelTaskTool.perform(context)
    }

    func cancelEvent(_ context: CommandContext) async -> ToolResult {
        return await cancelEventTool.perform(context)
    }

    func planWeek(_ context: CommandContext) async -> ToolResult {
        return await planWeekTool.perform(context)
    }

    func planDay(_ context: CommandContext) async -> ToolResult {
        return await planDayTool.perform(context)
    }

    func showAgenda(_ context: CommandContext) async -> ToolResult {
        return await showAgendaTool.perform(context)
    }

    func moreInfo(_ context: CommandContext) async -> ToolResult {
        return await moreInfoTool.perform(context)
    }

    func unknown(_ context: CommandContext) async -> ToolResult {
        return await unknownTool.perform(context)
    }
}
