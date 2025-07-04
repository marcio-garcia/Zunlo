//
//  EventRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

struct EventRemote: Codable, Identifiable {
    var id: UUID?
    var userId: UUID?
    var title: String
    var createdAt: Date?
    var dueDate: Date
    var recurrence: RecurrenceRule
    var exceptions: [Date]
    var isComplete: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case createdAt = "created_at"
        case dueDate = "due_date"
        case recurrence
        case exceptions
        case isComplete = "is_complete"
    }
    
    internal init(id: UUID? = nil,
                  userId: UUID? = nil,
                  title: String,
                  createdAt: Date? = nil,
                  dueDate: Date,
                  recurrence: RecurrenceRule,
                  exceptions: [Date] = [],
                  isComplete: Bool) {
        self.id = id
        self.userId = userId
        self.title = title
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.recurrence = recurrence
        self.exceptions = exceptions
        self.isComplete = isComplete
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeSafely(UUID.self, forKey: .id)
        self.userId = try container.decodeSafely(UUID.self, forKey: .userId)
        self.title = try container.decodeSafely(String.self, forKey: .title)
        self.isComplete = try container.decodeSafely(Bool.self, forKey: .isComplete)
        self.recurrence = try container.decode(RecurrenceRule.self, forKey: .recurrence)
        
        let createdAt = try container.decodeSafely(String.self, forKey: .createdAt)
        let dueDate = try container.decodeSafely(String.self, forKey: .dueDate)
        let exceptions = try container.decode([String].self, forKey: .exceptions)
        
        self.createdAt = DateFormatter.iso8601WithFractionalSeconds.date(from: createdAt)
        
        self.dueDate = Date()
        if let date = DateFormatter.iso8601WithoutFractionalSeconds.date(from: dueDate) {
            self.dueDate = date
        }
        
        self.exceptions = exceptions.compactMap({ dateString in
            return DateFormatter.iso8601WithoutFractionalSeconds.date(from: dateString)
        })
    }
}
