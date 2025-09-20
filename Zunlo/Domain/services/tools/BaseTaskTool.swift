//
//  BaseTaskTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Base Task Tool

/// Base class for task-related tools with shared functionality
class BaseTaskTool {
    let tasks: TaskStore
    let referenceDate: Date
    let calendar: Calendar

    init(tasks: TaskStore, referenceDate: Date, calendar: Calendar = .appDefault) {
        self.tasks = tasks
        self.calendar = calendar
        self.referenceDate = referenceDate
    }

    // MARK: - Common Task Filtering

    func filterTasksForOperation(
        _ tasks: [UserTask],
        command: ParseResult,
        excludeCompleted: Bool = true,
        allowPastTasks: Bool = false,
        referenceDate: Date
    ) -> [UserTask] {

        let context = command.context

        return tasks.filter { task in
            // 1. Optionally exclude completed tasks
            if excludeCompleted && task.isCompleted {
                return false
            }

            // 2. Basic title matching if provided
            if !command.title.isEmpty {
                let titleMatch = task.title.localizedCaseInsensitiveContains(command.title)
                if !titleMatch {
                    return false
                }
            }

            // 3. Handle past tasks
            if let dueDate = task.dueDate {
                if !allowPastTasks && dueDate < referenceDate {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - Common Selection Handling

    func handleTaskSelection(
        _ candidates: [UserTask],
        command: ParseResult,
        intent: Intent,
        performAction: (UserTask) async -> ToolResult
    ) async -> ToolResult {

        if candidates.isEmpty {
            return createNoMatchResult(command: command, intent: intent)
        }

        if candidates.count == 1 {
            return await performAction(candidates[0])
        }

        // Multiple candidates - need disambiguation
        return createDisambiguationResult(
            alternatives: candidates,
            command: command,
            intent: intent,
            message: "I found multiple tasks. Which one would you like to \(getActionVerb(for: intent))?".localized
        )
    }

    // MARK: - Common Disambiguation Results

    func createDisambiguationResult(
        alternatives: [UserTask],
        command: ParseResult,
        intent: Intent,
        message: String
    ) -> ToolResult {

        let options = alternatives.map { task in
            ChatMessageActionAlternative(
                id: task.id,
                parseResultId: command.id,
                intentOption: intent,
                editEventMode: nil,
                label: AttributedString(taskLabel(task))
            )
        }

        return ToolResult(
            intent: command.intent,
            action: .none,
            needsDisambiguation: true,
            options: options,
            message: message
        )
    }

    func createNoMatchResult(
        command: ParseResult,
        intent: Intent
    ) -> ToolResult {

        let actionVerb = getActionVerb(for: intent)
        let message: String

        if command.title.isEmpty {
            message = "Please specify which task you'd like to \(actionVerb).".localized
        } else {
            message = String(format: "I couldn't find a task matching '%@' to \(actionVerb). Could you be more specific?".localized, command.title)
        }

        return ToolResult(
            intent: command.intent,
            action: .none,
            needsDisambiguation: true,
            options: [],
            message: message
        )
    }

    // MARK: - Helper Methods

    private func getActionVerb(for intent: Intent) -> String {
        switch intent {
        case .cancelTask: return "cancel"
        case .updateTask: return "update"
        case .rescheduleTask: return "reschedule"
        default: return "modify"
        }
    }

    func taskLabel(_ task: UserTask) -> String {
        let title = !task.title.isEmpty ? task.title : "(no title)".localized
        if let dueDate = task.dueDate {
            return "\(title) — due \(formatDate(dueDate))"
        } else {
            return title
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func buildTaskInput(from task: UserTask, newTitle: String? = nil, newDueDate: Date? = nil, newNotes: String? = nil, newPriority: TaskPriority? = nil) -> EditTaskInput {
        EditTaskInput(
            id: task.id,
            userId: task.userId,
            title: newTitle ?? task.title,
            notes: newNotes ?? task.notes,
            dueDate: newDueDate ?? task.dueDate,
            isCompleted: task.isCompleted,
            priority: newPriority == nil ? task.priority : UserTaskPriority.fromParseResult(priority: newPriority!),
            parentEventId: task.parentEventId,
            tags: task.tags,
            reminderTriggers: task.reminderTriggers,
            deleteAt: task.deletedAt
        )
    }
}
