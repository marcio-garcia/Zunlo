//
//  Event.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

struct Event: Codable, Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let dueDate: Date
    let isComplete: Bool
    let userId: UUID
    
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case dueDate = "due_date"
        case isComplete = "is_complete"
        case userId = "user_id"
    }
}
