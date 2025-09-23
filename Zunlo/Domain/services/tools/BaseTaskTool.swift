//
//  BaseTaskTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SwiftUI
import SmartParseKit
import GlowUI

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
        context: CommandContext,
        excludeCompleted: Bool = true,
        allowPastTasks: Bool = false,
        referenceDate: Date
    ) -> [UserTask] {

        let temporalContext = context.temporalContext

        return tasks.filter { task in
            // 1. Optionally exclude completed tasks
            if excludeCompleted && task.isCompleted {
                return false
            }

            // 2. Basic title matching if provided
            if !context.title.isEmpty {
                let titleMatch = task.title.localizedCaseInsensitiveContains(context.title)
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
        context: CommandContext,
        intent: Intent,
        performAction: (UserTask) async -> ToolResult
    ) async -> ToolResult {

        if candidates.isEmpty {
            return createNoMatchResult(context: context, intent: intent)
        }

        if candidates.count == 1 {
            return await performAction(candidates[0])
        }

        // Multiple candidates - need disambiguation
        return createDisambiguationResult(
            alternatives: candidates,
            context: context,
            intent: intent,
            message: "I found multiple tasks. Which one would you like to \(getActionVerb(for: intent))?".localized
        )
    }

    // MARK: - Common Disambiguation Results

    func createDisambiguationResult(
        alternatives: [UserTask],
        context: CommandContext,
        intent: Intent,
        message: String
    ) -> ToolResult {

        let options = alternatives.map { task in
            ChatMessageActionAlternative(
                id: UUID(),  // Generate new UUID for disambiguation choice
                commandContextId: context.id,
                intentOption: intent,
                editEventMode: nil,
                label: taskLabel(task),
                taskId: task.id  // Store the task ID
            )
        }

        return ToolResult(
            intent: context.intent,
            action: .none,
            needsDisambiguation: true,
            options: options,
            message: message
        )
    }

    func createNoMatchResult(
        context: CommandContext,
        intent: Intent
    ) -> ToolResult {

        let actionVerb = getActionVerb(for: intent)
        let message: String

        if context.title.isEmpty {
            message = "Please specify which task you'd like to \(actionVerb).".localized
        } else {
            message = String(format: "I couldn't find a task matching '%@' to \(actionVerb). Could you be more specific?".localized, context.title)
        }

        return ToolResult(
            intent: context.intent,
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

    func taskLabel(_ task: UserTask) -> AttributedString {
        var attributedLabel = AttributedString()

        // Task title (bold, primary text color)
        let title = !task.title.isEmpty ? task.title : "(no title)".localized
        var titleText = AttributedString(title)
        titleText.font = AppFontStyle.body.weight(.bold).uiFont()
        titleText.foregroundColor = UIColor(Color.theme.text)
        attributedLabel += titleText

        // Due date if available
        if let dueDate = task.dueDate {
            // Separator
            var separator = AttributedString(" — ")
            separator.font = AppFontStyle.body.weight(.semibold).uiFont()
            separator.foregroundColor = UIColor(Color.theme.secondaryText)
            attributedLabel += separator

            // "due" label (caption, secondary text color)
            var dueLabel = AttributedString("due ")
            dueLabel.font = AppFontStyle.caption.uiFont()
            dueLabel.foregroundColor = UIColor(Color.theme.secondaryText)
            attributedLabel += dueLabel

            // Due date (medium weight, secondary text color)
            var dateText = AttributedString(formatDay(dueDate))
            dateText.font = AppFontStyle.body.weight(.medium).uiFont()
            dateText.foregroundColor = UIColor(Color.theme.secondaryText)
            attributedLabel += dateText
        }

        return attributedLabel
    }
    
    func formatDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
