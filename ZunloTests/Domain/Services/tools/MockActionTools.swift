//
//  MockActionTools.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/13/25.
//

import Foundation
import SmartParseKit
@testable import Zunlo

/// A test double for `ActionTools` (actually for the `Tools` protocol).
/// - Records calls & arguments
/// - Supports per-method return queues (FIFO)
/// - Supports per-method async closures for custom behavior
/// - Provides a sensible default `ToolResult` when nothing is stubbed
public final class MockActionTools: Tools {

    // MARK: - Call Records

    public private(set) var createTaskCalls: [CommandContext] = []
    public private(set) var createEventCalls: [CommandContext] = []
    public private(set) var rescheduleTaskCalls: [CommandContext] = []
    public private(set) var rescheduleEventCalls: [CommandContext] = []
    public private(set) var updateTaskCalls: [CommandContext] = []
    public private(set) var updateEventCalls: [CommandContext] = []
    public private(set) var cancelTaskCalls: [CommandContext] = []
    public private(set) var cancelEventCalls: [CommandContext] = []
    public private(set) var planWeekCalls: [CommandContext] = []
    public private(set) var planDayCalls: [CommandContext] = []
    public private(set) var showAgendaCalls: [CommandContext] = []
    public private(set) var moreInfoCalls: [CommandContext] = []
    public private(set) var unknownCalls: [CommandContext] = []

    // MARK: - Stubs (Queues) & Closures

    public var createTaskQueue: [ToolResult] = []
    public var createEventQueue: [ToolResult] = []
    public var rescheduleTaskQueue: [ToolResult] = []
    public var rescheduleEventQueue: [ToolResult] = []
    public var updateTaskQueue: [ToolResult] = []
    public var updateEventQueue: [ToolResult] = []
    public var cancelTaskQueue: [ToolResult] = []
    public var cancelEventQueue: [ToolResult] = []
    public var planWeekQueue: [ToolResult] = []
    public var planDayQueue: [ToolResult] = []
    public var showAgendaQueue: [ToolResult] = []
    public var moreInfoQueue: [ToolResult] = []
    public var unknownQueue: [ToolResult] = []

    public var onCreateTask: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onCreateEvent: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onRescheduleTask: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onRescheduleEvent: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onUpdateTask: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onUpdateEvent: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onCancelTask: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onCancelEvent: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onPlanWeek: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onPlanDay: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onShowAgenda: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onMoreInfo: ((_ cmd: CommandContext) async -> ToolResult)?
    public var onUnknown: ((_ cmd: CommandContext) async -> ToolResult)?

    public init() {}

    // MARK: - Tools conformance

    public func createTask(_ cmd: CommandContext) async -> ToolResult {
        createTaskCalls.append(cmd)
        if let f = onCreateTask { return await f(cmd) }
        if !createTaskQueue.isEmpty { return createTaskQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func createEvent(_ cmd: CommandContext) async -> ToolResult {
        createEventCalls.append(cmd)
        if let f = onCreateEvent { return await f(cmd) }
        if !createEventQueue.isEmpty { return createEventQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func rescheduleTask(_ cmd: CommandContext) async -> ToolResult {
        rescheduleTaskCalls.append(cmd)
        if let f = onRescheduleTask { return await f(cmd) }
        if !rescheduleTaskQueue.isEmpty { return rescheduleTaskQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func rescheduleEvent(_ cmd: CommandContext) async -> ToolResult {
        rescheduleEventCalls.append(cmd)
        if let f = onRescheduleEvent { return await f(cmd) }
        if !rescheduleEventQueue.isEmpty { return rescheduleEventQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func updateTask(_ cmd: CommandContext) async -> ToolResult {
        updateTaskCalls.append(cmd)
        if let f = onUpdateTask { return await f(cmd) }
        if !updateTaskQueue.isEmpty { return updateTaskQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func updateEvent(_ cmd: CommandContext) async -> ToolResult {
        updateEventCalls.append(cmd)
        if let f = onUpdateEvent { return await f(cmd) }
        if !updateEventQueue.isEmpty { return updateEventQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func cancelTask(_ cmd: CommandContext) async -> Zunlo.ToolResult {
        cancelTaskCalls.append(cmd)
        if let f = onCancelTask { return await f(cmd) }
        if !cancelTaskQueue.isEmpty { return cancelTaskQueue.removeFirst() }
        return defaultResult(for: cmd)
    }
    
    public func cancelEvent(_ cmd: CommandContext) async -> Zunlo.ToolResult {
        cancelEventCalls.append(cmd)
        if let f = onCancelEvent { return await f(cmd) }
        if !cancelEventQueue.isEmpty { return cancelEventQueue.removeFirst() }
        return defaultResult(for: cmd)
    }
    
    public func planWeek(_ cmd: CommandContext) async -> ToolResult {
        planWeekCalls.append(cmd)
        if let f = onPlanWeek { return await f(cmd) }
        if !planWeekQueue.isEmpty { return planWeekQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func planDay(_ cmd: CommandContext) async -> ToolResult {
        planDayCalls.append(cmd)
        if let f = onPlanDay { return await f(cmd) }
        if !planDayQueue.isEmpty { return planDayQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func showAgenda(_ cmd: CommandContext) async -> ToolResult {
        showAgendaCalls.append(cmd)
        if let f = onShowAgenda { return await f(cmd) }
        if !showAgendaQueue.isEmpty { return showAgendaQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func moreInfo(_ cmd: CommandContext) async -> ToolResult {
        moreInfoCalls.append(cmd)
        if let f = onMoreInfo { return await f(cmd) }
        if !moreInfoQueue.isEmpty { return moreInfoQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func unknown(_ cmd: CommandContext) async -> ToolResult {
        unknownCalls.append(cmd)
        if let f = onUnknown { return await f(cmd) }
        if !unknownQueue.isEmpty { return unknownQueue.removeFirst() }
        return defaultResult(for: cmd, intent: .unknown)
    }

    // MARK: - Helpers

    /// Clears all recorded calls and stub queues/closures.
    public func reset() {
        createTaskCalls.removeAll()
        createEventCalls.removeAll()
        rescheduleTaskCalls.removeAll()
        rescheduleEventCalls.removeAll()
        updateTaskCalls.removeAll()
        updateEventCalls.removeAll()
        planWeekCalls.removeAll()
        planDayCalls.removeAll()
        showAgendaCalls.removeAll()
        moreInfoCalls.removeAll()
        unknownCalls.removeAll()

        createTaskQueue.removeAll()
        createEventQueue.removeAll()
        rescheduleTaskQueue.removeAll()
        rescheduleEventQueue.removeAll()
        updateTaskQueue.removeAll()
        updateEventQueue.removeAll()
        planWeekQueue.removeAll()
        planDayQueue.removeAll()
        showAgendaQueue.removeAll()
        moreInfoQueue.removeAll()
        unknownQueue.removeAll()

        onCreateTask = nil
        onCreateEvent = nil
        onRescheduleTask = nil
        onRescheduleEvent = nil
        onUpdateTask = nil
        onUpdateEvent = nil
        onPlanWeek = nil
        onPlanDay = nil
        onShowAgenda = nil
        onMoreInfo = nil
        onUnknown = nil
    }

    private func defaultResult(for cmd: CommandContext, intent override: Intent? = nil) -> ToolResult {
        ToolResult(
            intent: override ?? cmd.intent,
            action: .none,
            needsDisambiguation: false,
            options: [],
            message: "MOCK: no stub set for \(cmd.intent.rawValue)"
        )
    }
}
