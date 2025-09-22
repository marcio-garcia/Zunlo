//
//  RescheduleTaskTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Reschedule Task Tool

/// Tool for rescheduling tasks to new due dates
final class RescheduleTaskTool: BaseTaskTool, ActionTool {

    // MARK: - ActionTool Conformance

    func perform(_ command: CommandContext) async -> ToolResult {
        do {
            // 1. Fetch all tasks
            let allTasks = try await tasks.fetchAll()

            // Check if user selected a specific entity
            if let id = command.selectedEntityId, let task = allTasks.first(where: { $0.id == id }) {
                return await self.performTaskReschedule(task, command: command)
            }

            // 2. Filter tasks for reschedule context
            let relevantTasks = filterTasksForOperation(
                allTasks,
                context: command,
                excludeCompleted: true,
                allowPastTasks: true,
                referenceDate: referenceDate
            )

            // 3. Handle selection and perform reschedule
            return await handleTaskSelection(relevantTasks, context: command, intent: .rescheduleTask) { task in
                await self.performTaskReschedule(task, command: command)
            }

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Task Rescheduling

    private func performTaskReschedule(
        _ task: UserTask,
        command: CommandContext
    ) async -> ToolResult {

        do {
            guard let newDueDate = extractNewDueDate(from: command, originalTask: task) else {
                return ToolResult(
                    intent: command.intent,
                    action: .none,
                    needsDisambiguation: false,
                    options: [],
                    message: "Please specify the new due date for the task.".localized
                )
            }

            let taskInput = buildTaskInput(from: task, newDueDate: newDueDate)

            try await tasks.update(
                id: task.id,
                title: taskInput.title,
                dueDate: taskInput.dueDate,
                tags: taskInput.tags.compactMap({ $0.text }),
                reminderTriggers: taskInput.reminderTriggers,
                priority: taskInput.priority,
                notes: taskInput.notes
            )

            return ToolResult(
                intent: command.intent,
                action: .rescheduledTask(id: task.id, due: newDueDate),
                needsDisambiguation: false,
                options: [],
                message: String(format: "Rescheduled task '%@' to %@.".localized, task.title, formatDay(newDueDate))
            )

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: "Failed to reschedule task: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Due Date Extraction

    private func extractNewDueDate(from command: CommandContext, originalTask: UserTask) -> Date? {
        let context = command.temporalContext

        // If there's a specific new date in the context, use it
        if let dateRange = context.dateRange {
            return dateRange.start
        }

        // Use the final date from context if different from original
        if context.finalDate != originalTask.dueDate {
            return context.finalDate
        }

        return nil
    }
}
