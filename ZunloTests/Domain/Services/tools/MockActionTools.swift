//
//  MockActionTools.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/13/25.
//

import Foundation
import SmartParseKit
import Zunlo

/// A test double for `ActionTools` (actually for the `Tools` protocol).
/// - Records calls & arguments
/// - Supports per-method return queues (FIFO)
/// - Supports per-method async closures for custom behavior
/// - Provides a sensible default `ToolResult` when nothing is stubbed
public final class MockActionTools: Tools {

    // MARK: - Call Records

    public private(set) var createTaskCalls: [ParseResult] = []
    public private(set) var createEventCalls: [ParseResult] = []
    public private(set) var rescheduleTaskCalls: [ParseResult] = []
    public private(set) var rescheduleEventCalls: [ParseResult] = []
    public private(set) var updateTaskCalls: [ParseResult] = []
    public private(set) var updateEventCalls: [ParseResult] = []
    public private(set) var planWeekCalls: [ParseResult] = []
    public private(set) var planDayCalls: [ParseResult] = []
    public private(set) var showAgendaCalls: [ParseResult] = []
    public private(set) var moreInfoCalls: [ParseResult] = []
    public private(set) var unknownCalls: [ParseResult] = []

    // MARK: - Stubs (Queues) & Closures

    public var createTaskQueue: [ToolResult] = []
    public var createEventQueue: [ToolResult] = []
    public var rescheduleTaskQueue: [ToolResult] = []
    public var rescheduleEventQueue: [ToolResult] = []
    public var updateTaskQueue: [ToolResult] = []
    public var updateEventQueue: [ToolResult] = []
    public var planWeekQueue: [ToolResult] = []
    public var planDayQueue: [ToolResult] = []
    public var showAgendaQueue: [ToolResult] = []
    public var moreInfoQueue: [ToolResult] = []
    public var unknownQueue: [ToolResult] = []

    public var onCreateTask: ((_ cmd: ParseResult) async -> ToolResult)?
    public var onCreateEvent: ((_ cmd: ParseResult) async -> ToolResult)?
    public var onRescheduleTask: ((_ cmd: ParseResult) async -> ToolResult)?
    public var onRescheduleEvent: ((_ cmd: ParseResult) async -> ToolResult)?
    public var onUpdateTask: ((_ cmd: ParseResult) async -> ToolResult)?
    public var onUpdateEvent: ((_ cmd: ParseResult) async -> ToolResult)?
    public var onPlanWeek: ((_ cmd: ParseResult) async -> ToolResult)?
    public var onPlanDay: ((_ cmd: ParseResult) async -> ToolResult)?
    public var onShowAgenda: ((_ cmd: ParseResult) async -> ToolResult)?
    public var onMoreInfo: ((_ cmd: ParseResult) async -> ToolResult)?
    public var onUnknown: ((_ cmd: ParseResult) async -> ToolResult)?

    public init() {}

    // MARK: - Tools conformance

    public func createTask(_ cmd: ParseResult) async -> ToolResult {
        createTaskCalls.append(cmd)
        if let f = onCreateTask { return await f(cmd) }
        if !createTaskQueue.isEmpty { return createTaskQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func createEvent(_ cmd: ParseResult) async -> ToolResult {
        createEventCalls.append(cmd)
        if let f = onCreateEvent { return await f(cmd) }
        if !createEventQueue.isEmpty { return createEventQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func rescheduleTask(_ cmd: ParseResult) async -> ToolResult {
        rescheduleTaskCalls.append(cmd)
        if let f = onRescheduleTask { return await f(cmd) }
        if !rescheduleTaskQueue.isEmpty { return rescheduleTaskQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func rescheduleEvent(_ cmd: ParseResult) async -> ToolResult {
        rescheduleEventCalls.append(cmd)
        if let f = onRescheduleEvent { return await f(cmd) }
        if !rescheduleEventQueue.isEmpty { return rescheduleEventQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func updateTask(_ cmd: ParseResult) async -> ToolResult {
        updateTaskCalls.append(cmd)
        if let f = onUpdateTask { return await f(cmd) }
        if !updateTaskQueue.isEmpty { return updateTaskQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func updateEvent(_ cmd: ParseResult) async -> ToolResult {
        updateEventCalls.append(cmd)
        if let f = onUpdateEvent { return await f(cmd) }
        if !updateEventQueue.isEmpty { return updateEventQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func planWeek(_ cmd: ParseResult) async -> ToolResult {
        planWeekCalls.append(cmd)
        if let f = onPlanWeek { return await f(cmd) }
        if !planWeekQueue.isEmpty { return planWeekQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func planDay(_ cmd: ParseResult) async -> ToolResult {
        planDayCalls.append(cmd)
        if let f = onPlanDay { return await f(cmd) }
        if !planDayQueue.isEmpty { return planDayQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func showAgenda(_ cmd: ParseResult) async -> ToolResult {
        showAgendaCalls.append(cmd)
        if let f = onShowAgenda { return await f(cmd) }
        if !showAgendaQueue.isEmpty { return showAgendaQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func moreInfo(_ cmd: ParseResult) async -> ToolResult {
        moreInfoCalls.append(cmd)
        if let f = onMoreInfo { return await f(cmd) }
        if !moreInfoQueue.isEmpty { return moreInfoQueue.removeFirst() }
        return defaultResult(for: cmd)
    }

    public func unknown(_ cmd: ParseResult) async -> ToolResult {
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

    private func defaultResult(for cmd: ParseResult, intent override: Intent? = nil) -> ToolResult {
        ToolResult(
            intent: override ?? cmd.intent,
            action: .none,
            needsDisambiguation: false,
            options: [],
            message: "MOCK: no stub set for \(cmd.intent.rawValue)"
        )
    }
}
