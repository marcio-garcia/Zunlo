//
//  EventRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

struct EventRemote: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var title: String
    var createdAt: Date
    var dueDate: Date
    var isComplete: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case dueDate = "due_date"
        case isComplete = "is_complete"
        case userId = "user_id"
    }
}
