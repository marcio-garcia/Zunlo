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
        return lhs.timeBeforeDue == rhs.timeBeforeDue
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(timeBeforeDue)
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
