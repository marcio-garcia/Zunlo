//
//  UnknownTool.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/19/25.
//

import Foundation
import SmartParseKit

// MARK: - Unknown Tool

/// Tool for handling unknown or unrecognized intents
final class UnknownTool: ActionTool {

    init() {}

    // MARK: - ActionTool Conformance

    func perform(_ command: ParseResult) async -> ToolResult {
        let message = generateHelpfulMessage(for: command)

        return ToolResult(
            intent: command.intent,
            action: .info(message: message),
            needsDisambiguation: false,
            options: [],
            message: message
        )
    }

    // MARK: - Message Generation

    private func generateHelpfulMessage(for command: ParseResult) -> String {
        let userInput = command.originalText

        if userInput.isEmpty {
            return "I'm not sure what you'd like me to do. Try asking me to create an event, schedule a task, or check your agenda.".localized
        }

        // Provide contextual suggestions based on keywords
        let lowercaseInput = userInput.lowercased()

        if containsEventKeywords(lowercaseInput) {
            return "It looks like you want to work with events. Try phrases like:\n• 'Create meeting tomorrow at 2pm'\n• 'Cancel my 3pm appointment'\n• 'Show me today's schedule'".localized
        }

        if containsTaskKeywords(lowercaseInput) {
            return "It seems you want to manage tasks. You can try:\n• 'Create task to buy groceries'\n• 'Mark task as done'\n• 'Reschedule homework to Friday'".localized
        }

        if containsScheduleKeywords(lowercaseInput) {
            return "To view your schedule, try:\n• 'Show my agenda for today'\n• 'What's my schedule this week?'\n• 'Plan my day'".localized
        }

        // Generic helpful message
        return String(format: "I'm not sure how to help with '%@'. Here are some things I can do:\n\n• Create and manage events\n• Create and manage tasks\n• Show your schedule and agenda\n• Reschedule appointments\n\nTry being more specific about what you'd like me to do.".localized, userInput)
    }

    // MARK: - Keyword Detection

    private func containsEventKeywords(_ input: String) -> Bool {
        let eventKeywords = [
            "meeting", "appointment", "event", "schedule", "calendar",
            "reunião", "compromisso", "evento", "agendar", "calendário"
        ]
        return eventKeywords.contains { input.contains($0) }
    }

    private func containsTaskKeywords(_ input: String) -> Bool {
        let taskKeywords = [
            "task", "todo", "reminder", "do", "complete", "finish",
            "tarefa", "fazer", "completar", "terminar", "lembrete"
        ]
        return taskKeywords.contains { input.contains($0) }
    }

    private func containsScheduleKeywords(_ input: String) -> Bool {
        let scheduleKeywords = [
            "agenda", "schedule", "plan", "show", "view", "what's",
            "agenda", "cronograma", "plano", "mostrar", "ver", "o que"
        ]
        return scheduleKeywords.contains { input.contains($0) }
    }
}
