//
//  ReminderScheduler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/17/25.
//

import Foundation
import UserNotifications
import LoggingKit

protocol SchedulableReminderItem {
    var id: UUID { get }
    var title: String { get }
    var dueDateForReminder: Date? { get } // abstract due/reminder time
    var bodyDescription: String? { get }
    var reminderTriggers: [ReminderTrigger]? { get }
    var notificationCategoryIdentifier: String { get }
}

public struct ReminderTrigger: Equatable, Hashable, Codable {
    public var timeBeforeDue: TimeInterval // seconds before dueDate
    @NullCodable public var message: String?
    
    enum CodingKeys: String, CodingKey {
        case timeBeforeDue
        case message
    }
    
    public init(timeBeforeDue: TimeInterval, message: String?) {
        self.timeBeforeDue = timeBeforeDue
        self._message = NullCodable(wrappedValue: message)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.timeBeforeDue = try c.decode(TimeInterval.self, forKey: .timeBeforeDue)
        self._message = try c.decodeIfPresent(NullCodable<String>.self, forKey: .message)
                      ?? NullCodable(wrappedValue: nil)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(timeBeforeDue, forKey: .timeBeforeDue)
        try c.encode(_message, forKey: .message) // preserves explicit null
    }
    
    public func toLocal() -> ReminderTriggerLocal {
        ReminderTriggerLocal(timeBeforeDue: timeBeforeDue, message: message)
    }
    
    public static func == (lhs: ReminderTrigger, rhs: ReminderTrigger) -> Bool {
        return lhs.timeBeforeDue == rhs.timeBeforeDue && lhs.message == rhs.message
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(timeBeforeDue)
        hasher.combine(message)
    }
}

final class ReminderScheduler {

    init() {}

    func scheduleReminders(for item: SchedulableReminderItem) async throws {
        guard let dueDate = item.dueDateForReminder,
              let triggers = item.reminderTriggers, !triggers.isEmpty else {
            log("No reminders to schedule for \(item.title)", level: .debug, category: "Reminders")
            return
        }

        let center = UNUserNotificationCenter.current()
        let now = Date()
        var scheduledCount = 0

        for (index, trigger) in triggers.enumerated() {
            let fireDate = dueDate.addingTimeInterval(-trigger.timeBeforeDue)

            // Skip reminders for dates in the past
            guard fireDate > now else {
                log("Skipping past reminder at \(fireDate) for \(item.title)", level: .debug, category: "Reminders")
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = trigger.message ?? item.bodyDescription ?? ""
            content.sound = .default
            content.categoryIdentifier = item.notificationCategoryIdentifier
            content.userInfo = [
                "id": item.id.uuidString,
                "categoryIdentifier": item.notificationCategoryIdentifier
            ]

            let components = Calendar.appDefault.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )

            let request = UNNotificationRequest(
                identifier: makeNotificationId(item.id, index),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            try await center.add(request)
            scheduledCount += 1
            log("Scheduled reminder at \(fireDate) for \(item.title)", level: .info, category: "Reminders")
        }

        if scheduledCount > 0 {
            log("Successfully scheduled \(scheduledCount) reminder(s) for \(item.title)", level: .info, category: "Reminders")
        }
    }

    /// Schedule reminders for multiple items in batch
    func scheduleReminders(for items: [SchedulableReminderItem]) async throws {
        log("Batch scheduling reminders for \(items.count) item(s)", level: .info, category: "Reminders")

        var successCount = 0
        var failureCount = 0

        for item in items {
            do {
                try await scheduleReminders(for: item)
                successCount += 1
            } catch {
                failureCount += 1
                log("Failed to schedule reminders for \(item.title): \(error.localizedDescription)", level: .error, category: "Reminders")
            }
        }

        log("Batch scheduling completed: \(successCount) succeeded, \(failureCount) failed", level: .info, category: "Reminders")
    }

    func cancelReminders(for item: SchedulableReminderItem) async {
        guard let triggers = item.reminderTriggers, !triggers.isEmpty else {
            log("No reminders to cancel for \(item.title)", level: .debug, category: "Reminders")
            return
        }

        await cancelReminders(itemId: item.id, reminderTriggers: triggers, itemTitle: item.title)
    }

    func cancelReminders(itemId: UUID, reminderTriggers: [ReminderTrigger], itemTitle: String = "Unknown") async {
        guard !reminderTriggers.isEmpty else { return }

        let identifiers = reminderTriggers.indices.map { makeNotificationId(itemId, $0) }

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
        
        log("Cancelled \(identifiers.count) reminder(s) for \(itemTitle)", level: .info, category: "Reminders")
    }

    /// Cancel reminders for multiple items in batch
    func cancelReminders(for items: [SchedulableReminderItem]) async {
        log("Batch cancelling reminders for \(items.count) item(s)", level: .info, category: "Reminders")

        for item in items {
            await cancelReminders(for: item)
        }

        log("Batch cancellation completed for \(items.count) item(s)", level: .info, category: "Reminders")
    }

    private func makeNotificationId(_ id: UUID, _ index: Int) -> String {
        return "reminder_\(id.uuidString)_\(index)"
    }
}

// MARK: Rescheduling

extension ReminderScheduler {
    
    private static let lastReminderScheduleKey = "sync.reminders.last.schedule.date"
    
    /// Remove all pending notifications for this app
    /// Used before full reschedule to ensure clean slate
    func clearAllReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        log("Clearing \(pending.count) pending notifications before reschedule", level: .debug, category: "Sync")

        center.removeAllPendingNotificationRequests()
    }
    
    /// Reschedule all future reminders after sync
    /// Called when data is pulled from server (reinstall, new device, etc.)
    func rescheduleRemindersAfterSync(db: DatabaseActor, auth: AuthProviding) async throws {
        log("Rescheduling reminders after sync", level: .info, category: "Sync")

        guard try await auth.isAuthorized(), let userId = await auth.userId else {
            return
        }
        
        let now = Date()

        // Fetch all tasks and events with future due dates
        do {
            // Fetch tasks
            let allTasks = try await db.fetchAllUserTasks(userId: userId)
            let futureTasks = allTasks.filter {
                guard let dueDate = $0.dueDate else { return false }
                return dueDate > now && $0.reminderTriggers?.isEmpty == false
            }

            // Fetch events
            let allEvents = try await db.fetchOccurrences(userId: userId)
            let futureEvents = allEvents
                .map { EventOccurrence(occ: $0) }
                .filter {
                    $0.startDate > now && $0.reminderTriggers?.isEmpty == false
                }
            
            // Clear ALL pending reminders first for clean slate
            // This is more efficient than iOS replacing each one individually
            await clearAllReminders()

            try? await scheduleReminders(for: futureTasks)
            try? await scheduleReminders(for: futureEvents)

            log("Rescheduled \(futureTasks.count) task reminders and \(futureEvents.count) event reminders",
                level: .info, category: "Sync")
        } catch {
            log("Failed to reschedule reminders: \(error.localizedDescription)", level: .error, category: "Sync")
        }
    }

    // MARK: - Reminder Scheduling Tracking

    func hasScheduledRemindersThisSession() -> Bool {
        // Check if last schedule was recent (within 12 hours)
        // This prevents rescheduling on every sync while still catching reinstalls
        guard let lastSchedule = UserDefaults.standard.object(forKey: Self.lastReminderScheduleKey) as? Date else {
            log("No previous reminder schedule found, will reschedule", level: .debug, category: "Sync")
            return false
        }

        let hoursSinceLastSchedule = Date().timeIntervalSince(lastSchedule) / 3600

        if hoursSinceLastSchedule < 12 {
            log("Reminders were scheduled \(Int(hoursSinceLastSchedule)) hours ago, skipping reschedule",
                level: .debug, category: "Sync")
            return true
        } else {
            log("Last schedule was \(Int(hoursSinceLastSchedule)) hours ago (>12h), will reschedule",
                level: .debug, category: "Sync")
            return false
        }
    }

    func markRemindersScheduledThisSession() {
        UserDefaults.standard.set(Date(), forKey: Self.lastReminderScheduleKey)
    }
}
