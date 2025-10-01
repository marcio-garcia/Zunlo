//
//  MockChatRepository.swift
//  Zunlo
//
//  Created for UI Testing with App Store friendly chat messages
//

import Foundation

/// Mock repository that provides App Store friendly chat messages for screenshots
final class MockChatRepository: ChatRepository {
    private var messages: [ChatMessage] = []

    init() {
        setupMockMessages()
    }

    private func setupMockMessages() {
        let conversationId = UUID()
        let now = Date()

        // Create a conversation showcasing the app's AI assistant capabilities
        messages = [
            // User asks to create a task
            ChatMessage(
                conversationId: conversationId,
                role: .user,
                plain: "Can you help me add a task to finish the quarterly report by Friday?",
                createdAt: now.addingTimeInterval(-300), // 5 minutes ago
                status: .sent
            ),

            // Assistant confirms task creation
            ChatMessage(
                conversationId: conversationId,
                role: .assistant,
                markdown: "I've created a task for you:\n\n**Finish quarterly report**\nDue: This Friday\n\nWould you like me to set a reminder for this?",
                createdAt: now.addingTimeInterval(-280),
                status: .sent
            ),

            // User asks about schedule
            ChatMessage(
                conversationId: conversationId,
                role: .user,
                plain: "What's on my schedule for today?",
                createdAt: now.addingTimeInterval(-200),
                status: .sent
            ),

            // Assistant shows today's schedule
            ChatMessage(
                conversationId: conversationId,
                role: .assistant,
                markdown: "Here's your schedule for today:\n\n**Morning**\n• 9:00 AM - Team standup\n• 10:30 AM - Project review meeting\n\n**Afternoon**\n• 2:00 PM - Client presentation\n• 4:00 PM - Focus time for quarterly report\n\nYou have 2 hours of focus time scheduled. Need me to adjust anything?",
                createdAt: now.addingTimeInterval(-180),
                status: .sent
            ),

            // User asks for planning help
            ChatMessage(
                conversationId: conversationId,
                role: .user,
                plain: "Can you suggest the best time to work on the report?",
                createdAt: now.addingTimeInterval(-100),
                status: .sent
            ),

            // Assistant provides intelligent suggestions
            ChatMessage(
                conversationId: conversationId,
                role: .assistant,
                markdown: "Based on your calendar, I recommend:\n\n**Thursday, 2:00 PM - 5:00 PM**\n• No meetings scheduled\n• Historically your most productive time\n• Gives you buffer time before Friday deadline\n\nShall I block this time on your calendar?",
                createdAt: now.addingTimeInterval(-80),
                status: .sent
            ),

            // User confirms
            ChatMessage(
                conversationId: conversationId,
                role: .user,
                plain: "Yes, please do that!",
                createdAt: now.addingTimeInterval(-30),
                status: .sent
            ),

            // Assistant confirms action
            ChatMessage(
                conversationId: conversationId,
                role: .assistant,
                markdown: "✓ Done! I've blocked Thursday 2-5 PM for \"Quarterly Report - Focus Time\"\n\nYou're all set. I'll send you a reminder on Thursday morning. Good luck!",
                createdAt: now.addingTimeInterval(-10),
                status: .sent
            )
        ]
    }

    // MARK: - ChatRepository Implementation

    func loadMessages(conversationId: UUID, limit: Int?) async throws -> [ChatMessage] {
        let messagesToReturn = limit.map { Array(messages.prefix($0)) } ?? messages
        return messagesToReturn
    }

    func upsert(_ message: ChatMessage) async throws {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            messages.append(message)
        }
    }

    func appendDelta(messageId: UUID, delta: String, status: ChatMessageStatus) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index].rawText += delta
        messages[index].status = status
    }

    func setStatus(messageId: UUID, status: ChatMessageStatus, error: String?) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index].status = status
        if let error = error {
            messages[index].errorDescription = error
        }
    }

    func delete(messageId: UUID) async throws {
        messages.removeAll { $0.id == messageId }
    }

    func deleteAll(_ conversationId: UUID) async throws {
        messages.removeAll { $0.conversationId == conversationId }
    }

    func setFormat(messageId: UUID, format: ChatMessageFormat) async throws {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index].format = format
    }
}
