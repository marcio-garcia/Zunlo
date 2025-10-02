//
//  DemoDataGenerator.swift
//  Zunlo
//
//  Demo data for Apple App Store review
//

#if DEBUG
import Foundation
import RealmSwift

/// Generates realistic demo data for Apple reviewers
final class DemoDataGenerator {

    private let userId: UUID
    private let db: DatabaseActor
    private var conversationId: UUID?

    init(userId: UUID, db: DatabaseActor) {
        self.userId = userId
        self.db = db
    }

    /// Main method to populate demo data
    func generateDemoData() async throws {
        print("🎭 Generating demo data for user: \(userId)")

        print(" Skip demo data for user: \(userId)")
//        try await generateTasks()
//        try await generateEvents()
        try await generateChatMessages()

        print("✅ Demo data generated successfully!")
    }

    // MARK: - Tasks

    private func generateTasks() async throws {
        let now = Date()
        let calendar = Calendar.current

        let tasks: [UserTask] = [
            // High priority - overdue
            UserTask(
                id: UUID(),
                userId: userId,
                title: "Submit Q1 financial report",
                notes: "Includes revenue analysis, expense breakdown, and projections for Q2",
                isCompleted: false,
                createdAt: calendar.date(byAdding: .day, value: -7, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -7, to: now)!,
                dueDate: calendar.date(byAdding: .day, value: -2, to: now)!,
                priority: .high,
                tags: [
                    Tag(id: UUID(), text: "work", color: "", selected: false),
                    Tag(id: UUID(), text: "finance", color: "", selected: false)
                ]
            ),

            // High priority - due today
            UserTask(
                id: UUID(),
                userId: userId,
                title: "Review contract with new vendor",
                notes: "Check pricing terms, delivery schedule, and payment conditions",
                isCompleted: false,
                createdAt: calendar.date(byAdding: .day, value: -3, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -3, to: now)!,
                dueDate: calendar.startOfDay(for: now),
                priority: .high,
                tags: [
                    Tag(id: UUID(), text: "work", color: "", selected: false),
                    Tag(id: UUID(), text: "legal", color: "", selected: false)
                ]
            ),

            // Medium priority - upcoming
            UserTask(
                id: UUID(),
                userId: userId,
                title: "Prepare slides for team presentation",
                notes: "Include project timeline, milestones achieved, and next steps",
                isCompleted: false,
                createdAt: calendar.date(byAdding: .day, value: -5, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -5, to: now)!,
                dueDate: calendar.date(byAdding: .day, value: 3, to: now)!,
                priority: .medium,
                tags: [
                    Tag(id: UUID(), text: "work", color: "", selected: false),
                    Tag(id: UUID(), text: "presentation", color: "", selected: false)
                ]
            ),

            UserTask(
                id: UUID(),
                userId: userId,
                title: "Book flight for conference",
                notes: "Tech Summit 2025 in San Francisco, October 15-17",
                isCompleted: false,
                createdAt: calendar.date(byAdding: .day, value: -4, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -4, to: now)!,
                dueDate: calendar.date(byAdding: .day, value: 5, to: now)!,
                priority: .medium,
                tags: [
                    Tag(id: UUID(), text: "travel", color: "", selected: false),
                    Tag(id: UUID(), text: "conference", color: "", selected: false)
                ]
            ),

            UserTask(
                id: UUID(),
                userId: userId,
                title: "Update project documentation",
                notes: "Add API endpoints documentation and usage examples",
                isCompleted: false,
                createdAt: calendar.date(byAdding: .day, value: -2, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -2, to: now)!,
                dueDate: calendar.date(byAdding: .day, value: 7, to: now)!,
                priority: .medium,
                tags: [
                    Tag(id: UUID(), text: "work", color: "", selected: false),
                    Tag(id: UUID(), text: "documentation", color: "", selected: false)
                ]
            ),

            // Low priority
            UserTask(
                id: UUID(),
                userId: userId,
                title: "Research new productivity tools",
                notes: "Compare features, pricing, and integration options",
                isCompleted: false,
                createdAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                dueDate: calendar.date(byAdding: .day, value: 14, to: now)!,
                priority: .low,
                tags: [
                    Tag(id: UUID(), text: "research", color: "", selected: false)
                ]
            ),

            UserTask(
                id: UUID(),
                userId: userId,
                title: "Schedule dentist appointment",
                notes: "Annual checkup and cleaning",
                isCompleted: false,
                createdAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -1, to: now)!,
                dueDate: nil,
                priority: .low,
                tags: [
                    Tag(id: UUID(), text: "personal", color: "", selected: false),
                    Tag(id: UUID(), text: "health", color: "", selected: false)
                ]
            ),

            // Completed tasks (to show functionality)
            UserTask(
                id: UUID(),
                userId: userId,
                title: "Send weekly status report",
                notes: "Team progress update for stakeholders",
                isCompleted: true,
                createdAt: calendar.date(byAdding: .day, value: -6, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -5, to: now)!,
                dueDate: calendar.date(byAdding: .day, value: -5, to: now)!,
                priority: .high,
                tags: [
                    Tag(id: UUID(), text: "work", color: "", selected: false),
                    Tag(id: UUID(), text: "reporting", color: "", selected: false)
                ]
            ),

            UserTask(
                id: UUID(),
                userId: userId,
                title: "Review pull requests",
                notes: "Code review for feature/user-authentication branch",
                isCompleted: true,
                createdAt: calendar.date(byAdding: .day, value: -4, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -4, to: now)!,
                dueDate: calendar.date(byAdding: .day, value: -4, to: now)!,
                priority: .medium,
                tags: [
                    Tag(id: UUID(), text: "work", color: "", selected: false),
                    Tag(id: UUID(), text: "code-review", color: "", selected: false)
                ]
            ),

            UserTask(
                id: UUID(),
                userId: userId,
                title: "Order office supplies",
                notes: "Notebooks, pens, sticky notes",
                isCompleted: true,
                createdAt: calendar.date(byAdding: .day, value: -3, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -2, to: now)!,
                dueDate: calendar.date(byAdding: .day, value: -2, to: now)!,
                priority: .low,
                tags: [
                    Tag(id: UUID(), text: "work", color: "", selected: false),
                    Tag(id: UUID(), text: "supplies", color: "", selected: false)
                ]
            )
        ]

        // Save tasks to database
        for task in tasks {
            try await db.upsertUserTask(from: task)
        }

        print("✅ Generated \(tasks.count) demo tasks")
    }

    // MARK: - Events

    private func generateEvents() async throws {
        let now = Date()
        let calendar = Calendar.current

        let events: [Event] = [
            // Today's events
            Event(
                id: UUID(),
                userId: userId,
                title: "Team standup",
                notes: "Daily sync with engineering team",
                startDate: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!,
                endDate: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: now)!,
                isRecurring: false,
                location: "Conference Room A",
                createdAt: calendar.date(byAdding: .day, value: -7, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -7, to: now)!,
                color: .blue
            ),

            Event(
                id: UUID(),
                userId: userId,
                title: "Client meeting - Product demo",
                notes: "Demo new features to Acme Corp. Attendees: Sarah (PM), John (Sales)",
                startDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now)!,
                endDate: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now)!,
                isRecurring: false,
                location: "Zoom",
                createdAt: calendar.date(byAdding: .day, value: -3, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -3, to: now)!,
                color: .green
            ),

            Event(
                id: UUID(),
                userId: userId,
                title: "Lunch with Alex",
                notes: "Catch up on project status",
                startDate: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: now)!,
                endDate: calendar.date(bySettingHour: 13, minute: 30, second: 0, of: now)!,
                isRecurring: false,
                location: "Downtown Cafe",
                createdAt: calendar.date(byAdding: .day, value: -2, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -2, to: now)!,
                color: .yellow
            ),

            // Tomorrow
            Event(
                id: UUID(),
                userId: userId,
                title: "Sprint planning",
                notes: "Plan work for next 2-week sprint",
                startDate: calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!)!,
                endDate: calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!)!,
                isRecurring: false,
                location: "Conference Room B",
                createdAt: calendar.date(byAdding: .day, value: -5, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -5, to: now)!,
                color: .purple
            ),

            Event(
                id: UUID(),
                userId: userId,
                title: "1-on-1 with manager",
                notes: "Quarterly review and career development discussion",
                startDate: calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now)!)!,
                endDate: calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: now)!)!,
                isRecurring: false,
                location: "Manager's office",
                createdAt: calendar.date(byAdding: .day, value: -4, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -4, to: now)!,
                color: .softOrange
            ),

            // This week
            Event(
                id: UUID(),
                userId: userId,
                title: "Workshop: Advanced Swift",
                notes: "Learn about async/await, actors, and structured concurrency",
                startDate: calendar.date(byAdding: .day, value: 3, to: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: now)!)!,
                endDate: calendar.date(byAdding: .day, value: 3, to: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now)!)!,
                isRecurring: false,
                location: "Training Room",
                createdAt: calendar.date(byAdding: .day, value: -10, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -10, to: now)!,
                color: .yellow
            ),

            Event(
                id: UUID(),
                userId: userId,
                title: "Product roadmap review",
                notes: "Q2 priorities and feature planning",
                startDate: calendar.date(byAdding: .day, value: 4, to: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: now)!)!,
                endDate: calendar.date(byAdding: .day, value: 4, to: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: now)!)!,
                isRecurring: false,
                location: "Executive Conference Room",
                createdAt: calendar.date(byAdding: .day, value: -6, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -6, to: now)!,
                color: .lightTeal
            ),

            // Next week
            Event(
                id: UUID(),
                userId: userId,
                title: "Company all-hands meeting",
                notes: "CEO update, new initiatives, Q&A session",
                startDate: calendar.date(byAdding: .day, value: 7, to: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!)!,
                endDate: calendar.date(byAdding: .day, value: 7, to: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: now)!)!,
                isRecurring: false,
                location: "Main Auditorium",
                createdAt: calendar.date(byAdding: .day, value: -14, to: now)!,
                updatedAt: calendar.date(byAdding: .day, value: -14, to: now)!,
                color: .powderBlue
            )
        ]

        // Save events to database
        for event in events {
            try await db.upsertEvent(from: EventLocal(domain: event))
        }

        print("✅ Generated \(events.count) demo events")
    }

    // MARK: - Chat Messages

    private func generateChatMessages() async throws {
        let now = Date()

        // Get the conversation ID that the chat is using
        do {
            conversationId = try DefaultsConversationIDStore().getOrCreate()
        } catch {
            print("Error getting conversation ID: \(error)")
            return
        }

        guard let conversationId = self.conversationId else { return }
        
        let messages: [ChatMessage] = [
            // Conversation 1: Task creation and management
            ChatMessage(
                conversationId: conversationId,
                role: .user,
                plain: "Add a task to finish the quarterly report by Friday",
                createdAt: now.addingTimeInterval(-3600), // 1 hour ago
                status: .sent,
                userId: userId
            ),

            ChatMessage(
                conversationId: conversationId,
                role: .assistant,
                markdown: "I've created a task for you:\n\n**Finish quarterly report**\n📅 Due: This Friday\n🔴 Priority: High\n\nWould you like me to set a reminder?",
                createdAt: now.addingTimeInterval(-3580),
                status: .sent,
                userId: userId
            ),

            ChatMessage(
                conversationId: conversationId,
                role: .user,
                plain: "Yes, remind me Thursday afternoon",
                createdAt: now.addingTimeInterval(-3500),
                status: .sent,
                userId: userId
            ),

            ChatMessage(
                conversationId: conversationId,
                role: .assistant,
                markdown: "✓ Done! I'll remind you on Thursday at 2:00 PM.\n\nIs there anything else I can help you with?",
                createdAt: now.addingTimeInterval(-3480),
                status: .sent,
                userId: userId
            ),

            // Recent conversation: Schedule query
            ChatMessage(
                conversationId: conversationId,
                role: .user,
                plain: "What's on my schedule for today?",
                createdAt: now.addingTimeInterval(-1800), // 30 minutes ago
                status: .sent,
                userId: userId
            ),

            ChatMessage(
                conversationId: conversationId,
                role: .assistant,
                markdown: "Here's your schedule for today:\n\n**Morning**\n• 9:00 AM - Team standup (30 min)\n• 12:30 PM - Lunch with Alex\n\n**Afternoon**\n• 2:00 PM - Client meeting - Product demo (1 hour)\n\nYou have a busy afternoon! The client demo is your most important meeting today.",
                createdAt: now.addingTimeInterval(-1780),
                status: .sent,
                userId: userId
            ),

            ChatMessage(
                conversationId: conversationId,
                role: .user,
                plain: "Show me my high priority tasks",
                createdAt: now.addingTimeInterval(-900), // 15 minutes ago
                status: .sent,
                userId: userId
            ),

            ChatMessage(
                conversationId: conversationId,
                role: .assistant,
                markdown: "Here are your **high priority** tasks:\n\n🔴 **Overdue:**\n• Submit Q1 financial report (due 2 days ago)\n\n🔴 **Due today:**\n• Review contract with new vendor\n\nI recommend tackling the financial report first since it's overdue. Would you like me to help break it down into smaller steps?",
                createdAt: now.addingTimeInterval(-880),
                status: .sent,
                userId: userId
            ),

            ChatMessage(
                conversationId: conversationId,
                role: .user,
                plain: "Create an event for tomorrow at 10am, Sprint planning meeting",
                createdAt: now.addingTimeInterval(-300), // 5 minutes ago
                status: .sent,
                userId: userId
            ),

            ChatMessage(
                conversationId: conversationId,
                role: .assistant,
                markdown: "✓ Event created!\n\n**Sprint planning**\n📅 Tomorrow at 10:00 AM\n📍 Would you like to add a location?\n⏰ Duration: 2 hours (default)\n\nI've added it to your calendar.",
                createdAt: now.addingTimeInterval(-280),
                status: .sent,
                userId: userId
            ),

            // Most recent message
            ChatMessage(
                conversationId: conversationId,
                role: .user,
                plain: "What tasks are due next week?",
                createdAt: now.addingTimeInterval(-60), // 1 minute ago
                status: .sent,
                userId: userId
            ),

            ChatMessage(
                conversationId: conversationId,
                role: .assistant,
                markdown: "Here are tasks due **next week**:\n\n📘 **Medium Priority:**\n• Book flight for conference (due in 5 days)\n• Update project documentation (due in 7 days)\n\nBoth are manageable. I suggest booking the flight soon to get better prices. Need help with that?",
                createdAt: now.addingTimeInterval(-50),
                status: .sent,
                userId: userId
            )
        ]

        // Ensure conversation exists
        try await db.ensureConversationExists(id: conversationId)

        // Save chat messages to database
        for message in messages {
            try await db.upsertChatMessage(message)
        }

        print("✅ Generated \(messages.count) demo chat messages")
    }

    /// Clears all demo data (useful for testing)
    func clearDemoData() async throws {
        print("🗑️ Clearing demo data for user: \(userId)")

        // Clear tasks
        let tasks = try await db.fetchUserTasks(filteredBy: nil, userId: userId)
        for task in tasks {
            try await db.deleteUserTask(id: task.id, userId: userId)
        }

        // Clear events
        try await db.deleteAllEvents(for: userId)

        // Clear chat messages (delete all conversations for this user)
        // Note: We'd need to get all conversation IDs first, but for demo purposes
        // we can create a method to clear all messages by userId if needed

        print("✅ Demo data cleared")
    }
    
    func clearDemoChat() async throws {
        print("🗑️ Clearing demo chat data for user: \(userId), conversation: \(try DefaultsConversationIDStore().getOrCreate())")
        
        guard let conversationId = self.conversationId else { return }
        
        try await db.deleteAllChatMessages(conversationId, userId: userId)
        
        print("✅ Demo chat data cleared")
    }
}

// MARK: - Demo Credentials

extension DemoDataGenerator {
    /// Demo account credentials for Apple reviewers
    static var demoCredentials: (email: String, password: String) {
        return (
            email: "demo@zunlo.app",
            password: "AppleReview2025!"
        )
    }

    /// Instructions for Apple reviewers
    static var reviewerInstructions: String {
        """
        # Demo Account for Apple Review

        **Email:** \(demoCredentials.email)
        **Password:** \(demoCredentials.password)

        ## What to Explore:

        ### Tasks (Inbox View)
        - View tasks organized by priority (High, Medium, Low)
        - Mark tasks as complete by tapping the checkbox
        - See overdue tasks highlighted in red
        - Create new tasks using the + button
        - Filter tasks by tags

        ### Calendar (Timeline View)
        - View today's schedule and upcoming events
        - See events in calendar view
        - Create new events
        - View event details by tapping

        ### AI Assistant (Chat View)
        - Natural language task creation: "Add task to finish report by Friday"
        - Schedule queries: "What's on my schedule for today?"
        - Task management: "Show me high priority tasks"
        - Event creation: "Create an event for tomorrow at 10am"
        - Smart parsing of dates, priorities, and context
        - **Demo conversation included** - See realistic AI interactions

        ### Today View
        - Quick overview of today's priorities
        - Upcoming events and deadlines
        - Quick actions for common tasks

        ## Sample Demo Data Included:
        - **10 realistic tasks** (mix of completed and pending)
          - High priority overdue items
          - Tasks due today, this week, and next week
          - Various tags (work, personal, health, etc.)
        - **8 calendar events** (meetings, workshops, appointments)
          - Today's schedule and upcoming week
          - Realistic meeting titles and locations
        - **12 chat messages** showing AI conversation flow
          - Task creation demonstration
          - Schedule inquiries
          - Priority task filtering
          - Natural language understanding
        - Various priorities, tags, and realistic contexts

        All features work with real backend (Supabase) for full functionality testing.
        """
    }
}
#endif
