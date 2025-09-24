//
//  CreateTaskTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Create Task Tool

/// Tool for creating new tasks
final class CreateTaskTool: BaseTaskTool, ActionTool {
    private let userId: UUID
    
    init(tasks: TaskStore, userId: UUID, referenceDate: Date, calendar: Calendar = .appDefault) {
        self.userId = userId
        super.init(tasks: tasks, referenceDate: referenceDate, calendar: calendar)
    }

    // MARK: - ActionTool Conformance

    func perform(_ context: CommandContext) async -> ToolResult {
        do {
            let taskInfo = extractTaskInfo(from: context)

            var tags: [Tag] = []
            if let tag = taskInfo.tag {
                tags.append(Tag(id: UUID(), text: tag, color: "", selected: false))
            }
            
            let task = UserTask(
                id: UUID(),
                userId: userId,
                title: taskInfo.title,
                notes: taskInfo.notes,
                isCompleted: false,
                dueDate: taskInfo.dueDate,
                priority: UserTaskPriority.fromParseResult(priority: taskInfo.priority),
                tags: tags
            )

            try await tasks.upsert(task)

            return ToolResult(
                intent: context.intent,
                action: .createdTask(id: task.id),
                needsDisambiguation: false,
                options: [],
                message: String(format: String(localized: "Created task '%@'."), taskInfo.title)
            )

        } catch {
            return ToolResult(
                intent: context.intent,
                action: .none,
                needsDisambiguation: false,
                options: [],
                message: String(localized: "Failed to create task: \(error.localizedDescription)")
            )
        }
    }

    // MARK: - Task Info Extraction

    private struct TaskInfo {
        let title: String
        let notes: String?
        let dueDate: Date?
        let priority: TaskPriority
        let tag: String?
    }

    private func extractTaskInfo(from context: CommandContext) -> TaskInfo {
        let temporalContext = context.temporalContext
        var notes: String?
        var priority: TaskPriority = .medium
        var tag: String?

        // Extract metadata from metadataTokens
        for token in context.metadataTokens {
            switch token.kind {
            case .notes(let noteText, _):
                notes = noteText
                
            case .priority(let taskPriority, _):
                priority = taskPriority
                
            case .tag(let name, _):
                tag = name
            default:
                break
            }
        }

        // Use title from context or fallback
        let title = !context.title.isEmpty ? context.title : String(localized: "New Task")

        // Extract due date from context
        let dueDate = temporalContext.dateRange?.start ?? temporalContext.finalDate

        return TaskInfo(
            title: title,
            notes: notes,
            dueDate: dueDate != Date().startOfDay(calendar: calendar) ? dueDate : nil,
            priority: priority,
            tag: tag
        )
    }
}
