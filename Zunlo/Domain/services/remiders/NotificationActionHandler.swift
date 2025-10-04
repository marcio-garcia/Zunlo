//
//  NotificationActionHandler.swift
//  Zunlo
//
//  Created by Claude Code
//

import Foundation
import UserNotifications
import LoggingKit

/// Handles user interactions with notification actions
/// Works for BOTH local reminders and remote push notifications
final class NotificationActionHandler {

    private let taskRepository: UserTaskRepository
    private let eventRepository: EventRepository

    init(taskRepository: UserTaskRepository, eventRepository: EventRepository) {
        self.taskRepository = taskRepository
        self.eventRepository = eventRepository
    }

    // MARK: - Notification Categories Setup

    /// Register all notification categories with their actions
    /// These categories work for BOTH:
    /// - Local notifications (scheduled reminders)
    /// - Remote notifications (push from server)
    static func registerNotificationCategories() {
        // Task reminder actions
        let completeAction = UNNotificationAction(
            identifier: NotificationAction.completeTask.rawValue,
            title: "✓ Mark Complete",
            options: [.authenticationRequired]
        )

        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snoozeTask.rawValue,
            title: "⏰ Snooze 1 hour",
            options: []
        )

        let taskCategory = UNNotificationCategory(
            identifier: NotificationCategory.taskReminder.rawValue,
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Event reminder actions
        let viewEventAction = UNNotificationAction(
            identifier: NotificationAction.viewEvent.rawValue,
            title: "📅 View Details",
            options: [.foreground]
        )

        let eventCategory = UNNotificationCategory(
            identifier: NotificationCategory.eventReminder.rawValue,
            actions: [viewEventAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current()
            .setNotificationCategories([taskCategory, eventCategory])

        log("Registered notification categories with actions (local + remote)", level: .info, category: "Notifications")
    }

    // MARK: - Action Handling

    /// Handle notification action response
    func handleNotificationAction(
        response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        guard let itemIdString = userInfo["id"] as? String,
              let itemId = UUID(uuidString: itemIdString),
              let categoryId = userInfo["categoryIdentifier"] as? String else {
            log("Invalid notification userInfo", level: .error, category: "Notifications")
            completionHandler()
            return
        }

        log("Handling notification action: \(response.actionIdentifier) for item: \(itemId)",
            level: .info, category: "Notifications")

        Task(priority: .userInitiated) {
            defer { completionHandler() }

            switch response.actionIdentifier {
            case NotificationAction.completeTask.rawValue:
                await handleCompleteTask(itemId: itemId)

            case NotificationAction.snoozeTask.rawValue:
                await handleSnoozeTask(itemId: itemId)

            case NotificationAction.viewEvent.rawValue:
                await handleViewEvent(itemId: itemId)

            case UNNotificationDefaultActionIdentifier:
                // User tapped notification (not an action button)
                log("User tapped notification for item: \(itemId)", level: .debug, category: "Notifications")

            case UNNotificationDismissActionIdentifier:
                // User dismissed notification
                log("User dismissed notification for item: \(itemId)", level: .debug, category: "Notifications")

            default:
                log("Unknown action: \(response.actionIdentifier)", level: .warn, category: "Notifications")
            }
        }
    }

    // MARK: - Private Action Handlers

    private func handleCompleteTask(itemId: UUID) async {
        log("Marking task complete: \(itemId)", level: .info, category: "Notifications")

        do {
            guard let task = try await taskRepository.fetchTask(id: itemId) else {
                log("Task not found: \(itemId)", level: .warn, category: "Notifications")
                return
            }

            var updatedTask = task
            updatedTask.isCompleted = true

            try await taskRepository.upsert(updatedTask)

            log("Task marked complete: \(task.title)", level: .info, category: "Notifications")

            // Show success feedback
            await showLocalNotification(
                title: "✓ Task Completed",
                body: task.title,
                identifier: "task-completed-\(itemId.uuidString)"
            )
        } catch {
            log("Failed to mark task complete: \(error.localizedDescription)", level: .error, category: "Notifications")
        }
    }

    private func handleSnoozeTask(itemId: UUID) async {
        log("Snoozing task: \(itemId)", level: .info, category: "Notifications")

        do {
            guard let task = try await taskRepository.fetchTask(id: itemId) else {
                log("Task not found: \(itemId)", level: .warn, category: "Notifications")
                return
            }

            guard let currentDueDate = task.dueDate else {
                log("Task has no due date, cannot snooze: \(itemId)", level: .warn, category: "Notifications")
                return
            }

            // Snooze for 1 hour
            let newDueDate = currentDueDate.addingTimeInterval(3600)

            var updatedTask = task
            updatedTask.dueDate = newDueDate

            try await taskRepository.upsert(updatedTask)

            log("Task snoozed until \(newDueDate): \(task.title)", level: .info, category: "Notifications")

            // Show success feedback
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            let timeString = dateFormatter.string(from: newDueDate)

            await showLocalNotification(
                title: "⏰ Task Snoozed",
                body: "\(task.title) - Reminder at \(timeString)",
                identifier: "task-snoozed-\(itemId.uuidString)"
            )
        } catch {
            log("Failed to snooze task: \(error.localizedDescription)", level: .error, category: "Notifications")
        }
    }

    private func handleViewEvent(itemId: UUID) async {
        log("Viewing event: \(itemId)", level: .info, category: "Notifications")

        // Event viewing will be handled by the app opening to the event detail
        // This is just for logging
        do {
            guard let event = try await eventRepository.fetchEvent(by: itemId) else {
                log("Event not found: \(itemId)", level: .warn, category: "Notifications")
                return
            }

            log("User viewing event: \(event.title)", level: .info, category: "Notifications")
        } catch {
            log("Failed to fetch event: \(error.localizedDescription)", level: .error, category: "Notifications")
        }
    }

    // MARK: - Helper Methods

    private func showLocalNotification(title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            log("Failed to show feedback notification: \(error.localizedDescription)",
                level: .error, category: "Notifications")
        }
    }
}

// MARK: - Notification Constants

enum NotificationCategory: String {
    case taskReminder = "TASK_REMINDER"
    case eventReminder = "EVENT_REMINDER"
}

enum NotificationAction: String {
    case completeTask = "COMPLETE_TASK"
    case snoozeTask = "SNOOZE_TASK"
    case viewEvent = "VIEW_EVENT"
}
