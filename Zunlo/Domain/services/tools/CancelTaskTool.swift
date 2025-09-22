//
//  CancelTaskTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Cancel Task Tool

/// Tool for canceling tasks
final class CancelTaskTool: BaseTaskTool, ActionTool {

    // MARK: - ActionTool Conformance

    func perform(_ context: CommandContext) async -> ToolResult {
        do {
            // 1. Fetch all tasks
            let allTasks = try await tasks.fetchAll()

            // 2. Filter tasks for cancel context
            let relevantTasks = filterTasksForOperation(
                allTasks,
                context: context,
                excludeCompleted: true,
                allowPastTasks: true,
                referenceDate: referenceDate
            )

            // 3. Handle selection and perform cancellation
            return await handleTaskSelection(relevantTasks, context: context, intent: .cancelTask) { task in
                await self.performTaskCancellation(task, command: context)
            }

        } catch {
            return ToolResult(
                intent: context.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Task Cancellation

    private func performTaskCancellation(
        _ task: UserTask,
        command: CommandContext
    ) async -> ToolResult {

        do {
            try await tasks.delete(taskId: task.id)

            return ToolResult(
                intent: command.intent,
                action: .canceledTask(id: task.id),
                needsDisambiguation: false,
                options: [],
                message: String(format: "Cancelled task '%@'.".localized, task.title)
            )

        } catch {
            return ToolResult(
                intent: command.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: "Failed to cancel task: \(error.localizedDescription)"
            )
        }
    }
}
