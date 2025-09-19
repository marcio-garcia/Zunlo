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
    func createTask(_ cmd: ParseResult) async -> ToolResult
    func createEvent(_ cmd: ParseResult) async -> ToolResult
    func rescheduleTask(_ cmd: ParseResult) async -> ToolResult
    func rescheduleEvent(_ cmd: ParseResult) async -> ToolResult
    func updateTask(_ cmd: ParseResult) async -> ToolResult
    func updateEvent(_ cmd: ParseResult) async -> ToolResult
    func cancelTask(_ cmd: ParseResult) async -> ToolResult
    func cancelEvent(_ cmd: ParseResult) async -> ToolResult
    func planWeek(_ cmd: ParseResult) async -> ToolResult
    func planDay(_ cmd: ParseResult) async -> ToolResult
    func showAgenda(_ cmd: ParseResult) async -> ToolResult
    func moreInfo(_ cmd: ParseResult) async -> ToolResult
    func unknown(_ cmd: ParseResult) async -> ToolResult
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
        self.createTaskTool = CreateTaskTool(tasks: tasks, userId: userId, calendar: calendar)
        self.updateTaskTool = UpdateTaskTool(tasks: tasks, calendar: calendar)
        self.cancelTaskTool = CancelTaskTool(tasks: tasks, calendar: calendar)
        self.rescheduleTaskTool = RescheduleTaskTool(tasks: tasks, calendar: calendar)
        self.planDayTool = PlanDayTool(events: events, calendar: calendar)
        self.planWeekTool = PlanWeekTool(events: events, calendar: calendar)
        self.showAgendaTool = ShowAgendaTool(events: events, calendar: calendar)
        self.moreInfoTool = MoreInfoTool(events: events, tasks: tasks, calendar: calendar)
        self.unknownTool = UnknownTool()
    }

    // MARK: - Tools Protocol Conformance

    func createTask(_ cmd: ParseResult) async -> ToolResult {
        return await createTaskTool.perform(cmd)
    }

    func createEvent(_ cmd: ParseResult) async -> ToolResult {
        return await createEventTool.perform(cmd)
    }

    func rescheduleTask(_ cmd: ParseResult) async -> ToolResult {
        return await rescheduleTaskTool.perform(cmd)
    }

    func rescheduleEvent(_ cmd: ParseResult) async -> ToolResult {
        return await rescheduleEventTool.perform(cmd)
    }

    func updateTask(_ cmd: ParseResult) async -> ToolResult {
        return await updateTaskTool.perform(cmd)
    }

    func updateEvent(_ cmd: ParseResult) async -> ToolResult {
        return await updateEventTool.perform(cmd)
    }

    func cancelTask(_ cmd: ParseResult) async -> ToolResult {
        return await cancelTaskTool.perform(cmd)
    }

    func cancelEvent(_ cmd: ParseResult) async -> ToolResult {
        return await cancelEventTool.perform(cmd)
    }

    func planWeek(_ cmd: ParseResult) async -> ToolResult {
        return await planWeekTool.perform(cmd)
    }

    func planDay(_ cmd: ParseResult) async -> ToolResult {
        return await planDayTool.perform(cmd)
    }

    func showAgenda(_ cmd: ParseResult) async -> ToolResult {
        return await showAgendaTool.perform(cmd)
    }

    func moreInfo(_ cmd: ParseResult) async -> ToolResult {
        return await moreInfoTool.perform(cmd)
    }

    func unknown(_ cmd: ParseResult) async -> ToolResult {
        return await unknownTool.perform(cmd)
    }
}
