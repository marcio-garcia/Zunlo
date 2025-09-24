//
//  UpdateTaskTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Update Task Tool

/// Tool for updating existing tasks
final class UpdateTaskTool: BaseTaskTool, ActionTool {

    // MARK: - ActionTool Conformance

    func perform(_ command: CommandContext) async -> ToolResult {
        do {
            // 1. Fetch all tasks
            let allTasks = try await tasks.fetchAll()

            // Check if user selected a specific entity
            if let id = command.selectedEntityId, let task = allTasks.first(where: { $0.id == id }) {
                return await self.performTaskUpdate(task, command: command)
            }

            // 2. Filter tasks for update context
            let relevantTasks = filterTasksForOperation(
                allTasks,
                context: command,
                excludeCompleted: false,
                allowPastTasks: true,
                referenceDate: referenceDate
            )

            // 3. Handle selection and perform update
            return await handleTaskSelection(relevantTasks, context: command, intent: .updateTask) { task in
                await self.performTaskUpdate(task, command: command)
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

    // MARK: - Task Updating

    private func performTaskUpdate(
        _ task: UserTask,
        command: CommandContext
    ) async -> ToolResult {

        do {
            let updateInfo = extractUpdateInfo(from: command, originalTask: task)

            let taskInput = buildTaskInput(
                from: task,
                newTitle: updateInfo.newTitle,
                newDueDate: updateInfo.newDueDate,
                newNotes: updateInfo.newNotes,
                newPriority: updateInfo.newPriority
            )

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
                action: .updatedTask(id: task.id),
                needsDisambiguation: false,
                options: [],
                message: String(format: String(localized: "Updated task '%@'."), updateInfo.newTitle ?? task.title)
            )

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: String(localized: "Failed to update task: \(error.localizedDescription)")
            )
        }
    }

    // MARK: - Update Info Extraction

    private struct UpdateInfo {
        let newTitle: String?
        let newNotes: String?
        let newDueDate: Date?
        let newPriority: TaskPriority?
    }

    private func extractUpdateInfo(from command: CommandContext, originalTask: UserTask) -> UpdateInfo {
        let context = command.temporalContext
        var newTitle: String?
        var newNotes: String?
        var newPriority: TaskPriority?

        // Extract metadata from metadataTokens
        for token in command.metadataTokens {
            switch token.kind {
            case .newTitle(let title, _):
                newTitle = title
            case .notes(let noteText, _):
                newNotes = noteText
            case .priority(let taskPriority, _):
                newPriority = taskPriority
            default:
                break
            }
        }

        // Extract new timing if provided
        var newDueDate: Date?
        if let dateRange = context.dateRange {
            newDueDate = dateRange.start
        } else if context.finalDate != originalTask.dueDate {
            newDueDate = context.finalDate
        }

        return UpdateInfo(
            newTitle: newTitle,
            newNotes: newNotes,
            newDueDate: newDueDate,
            newPriority: newPriority
        )
    }
}
