//
//  DefaultAIToolRunner.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

import Foundation
import FlowNavigator

public final class DefaultAIToolRunner: AIToolRunner {
    private let userId: UUID
    private let toolRepo: AIToolAPI
    private let calendar: Calendar
    private weak var nav: AppNav?

    init(
        userId: UUID,
        toolRepo: AIToolAPI,
        calendar: Calendar,
        nav: AppNav? = nil
    ) {
        self.userId = userId
        self.toolRepo = toolRepo
        self.calendar = calendar
        self.nav = nav
    }

    // MARK: Actions

    public func startDailyPlan(context: AIContext) async throws {
        // Simple v1: schedule one focus block for top candidate in the next free window.
        guard let win = context.nextWindow else {
            // Optionally open your "Planner" UI instead
            // await nav?.presentDailyPlanner()
            return
        }
        let mins = context.bestFocusDuration()
        let task = context.bestCandidateForNextWindow
        try await createFocusBlock(start: win.start, minutes: mins, suggestedTask: task)
        // Optional: open day plan sheet after booking the first anchor
        // await nav?.presentDailyPlanner()
    }

    func createFocusBlock(start: Date, minutes: Int, suggestedTask: UserTask?) async throws {
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        let title = "Focus" + (suggestedTask.map { ": \($0.title)" } ?? "")
        let notes = suggestedTask.map { "Suggested by AI for task \($0.title)" }

        do {
            let eventId = try await toolRepo.createEvent(
                from: EventDraft(
                    userId: userId,
                    title: title,
                    start: start,
                    end: end,
                    notes: notes,
                    linkedTaskId: suggestedTask?.id
                )
            )

            if var t = suggestedTask {
                // If your model is a struct, mutate a copy
                t.dueDate = end
                // t.estimatedMinutes = minutes
                try await toolRepo.updateTask(t)
            }

            // Optional: navigate to the newly created focus block
//            await nav?.showEventDetail(eventId: eventId)
        } catch {
            // Surface an in-app toast if you have one
//            await nav?.toast("Couldn’t create focus block.")
            throw AIToolRunnerError.failed("")
        }
    }

    func scheduleTask(_ task: UserTask, at start: Date, minutes: Int) async throws {
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        do {
            // 1) create a calendar block
            let eventId = try await toolRepo.createEvent(from: EventDraft(
                userId: userId,
                title: "Focus: \(task.title)",
                start: start,
                end: end,
                notes: "Linked to task \(task.id.uuidString)",
                linkedTaskId: task.id
            ))
            // 2) update the task’s scheduling fields
            var updated = task
            updated.dueDate = end
//            updated.estimatedMinutes = minutes
            try await toolRepo.updateTask(updated)
//            await nav?.showEventDetail(eventId: eventId)
        } catch {
//            await nav?.toast("Couldn’t schedule “\(task.title)”.")
            throw AIToolRunnerError.failed("")
        }
    }

    public func bookSlot(at start: Date, minutes: Int, title: String?) async throws {
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        do {
            _ = try await toolRepo.createEvent(from: EventDraft(
                userId: userId,
                title: title ?? "Focus",
                start: start,
                end: end,
                notes: nil,
                linkedTaskId: nil
            ))
//            await nav?.toast("Booked \(minutes) min at \(start.formatted(time: .shortened)).")
        } catch {
//            await nav?.toast("Couldn’t book the slot.")
            throw AIToolRunnerError.failed("")
        }
    }

    public func resolveConflictsToday() async throws {
        do {
            try await toolRepo.resolveConflictsToday()
//            await nav?.toast("Conflicts resolved.")
        } catch {
//            await nav?.toast("Couldn’t resolve conflicts.")
            throw AIToolRunnerError.failed("")
        }
    }

    public func addPrepTasksForNextEvent(userId: UUID, prepTemplate: PrepPackTemplate) async throws {
        do {
            let now = Date()
            if let next = try await toolRepo.nextUpcomingEvent(after: now) {
                // Create a small checklist as tasks due before the event
                let due = (next.start > now) ? next.start : now
                for item in prepTemplate.items {
                    _ = try await toolRepo.createTask(
                        userId: userId,
                        title: "\(item) — \(next.title)",
                        dueDate: due.addingTimeInterval(-30*60),
                        priority: .medium
                    )
                }
                // await nav?.toast("Added prep tasks for “\(next.title)”.")
            }
        } catch {
//            await nav?.toast("No upcoming event found.")
            throw AIToolRunnerError.failed("")
        }
    }

    public func shiftErrandsEarlierToday() async throws {
        // This is app-specific; here we just open a filtered view to nudge user action.
//        await nav?.presentFilteredTasks(tag: "Errands", suggestion: "Rain soon—do these earlier?")
    }

    public func startEveningWrap() async throws {
        // Optionally create a 15-min review block at 18:00 if there’s room
        let cal = calendar
        let now = Date()
        if let sixPM = cal.date(bySettingHour: 18, minute: 0, second: 0, of: cal.startOfDay(for: now)),
           sixPM > now {
            try await bookSlot(at: sixPM, minutes: 15, title: "Evening wrap")
        }
        try await toolRepo.moveUnfinishedToTomorrow()
//        await nav?.presentEveningReview()
    }
}
