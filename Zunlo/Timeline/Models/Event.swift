//
//  Event.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation
import SwiftData

@Model
class EventEntity: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var dueDate: Date?
    var isCompleted: Bool

    internal init(id: UUID = UUID(), title: String, dueDate: Date?, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
}


struct Event: Codable, Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let isComplete: Bool
    let userId: UUID
    
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case isComplete = "is_complete"
        case userId = "user_id"
    }
}
