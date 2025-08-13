//
//  ReminderScheduler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/17/25.
//

import Foundation
import UserNotifications

protocol SchedulableReminderItem {
    var id: UUID { get }
    var title: String { get }
    var dueDateForReminder: Date? { get } // abstract due/reminder time
    var reminderTriggers: [ReminderTrigger]? { get }
}

struct ReminderTrigger: Codable, Hashable {
    var timeBeforeDue: TimeInterval // seconds before dueDate
    var message: String?
    
    func toLocal() -> ReminderTriggerLocal {
        ReminderTriggerLocal(timeBeforeDue: timeBeforeDue, message: message)
    }
}

final class ReminderScheduler<T: SchedulableReminderItem> {

    init() {}

    func scheduleReminders(for item: T) {
        guard let dueDate = item.dueDateForReminder,
              let triggers = item.reminderTriggers else { return }

        let center = UNUserNotificationCenter.current()

        for (index, trigger) in triggers.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Reminder"
            content.body = trigger.message ?? item.title
            content.sound = .default
            content.userInfo = ["id": item.id.uuidString]

            let fireDate = dueDate.addingTimeInterval(-trigger.timeBeforeDue)
            let components = Calendar.appDefault.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )

            let request = UNNotificationRequest(
                identifier: makeNotificationId(item.id, index),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            center.add(request) { error in
                if let error = error {
                    print("⚠️ Failed to schedule reminder: \(error)")
                } else {
                    print("✅ Scheduled reminder at \(fireDate) for task \(item.title)")
                }
            }
        }
    }

    func cancelReminders(for item: T) {
        guard let triggers = item.reminderTriggers else { return }

        cancelReminders(itemId: item.id, reminderTriggers: triggers)
    }
    
    func cancelReminders(itemId: UUID, reminderTriggers: [ReminderTrigger]) {
        let identifiers = reminderTriggers.indices.map { makeNotificationId(itemId, $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func makeNotificationId(_ id: UUID, _ index: Int) -> String {
        return "reminder_\(id.uuidString)_\(index)"
    }
}
