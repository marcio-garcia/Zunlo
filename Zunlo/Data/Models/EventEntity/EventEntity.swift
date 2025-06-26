//
//  EventEntity.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation
import SwiftData

@Model
final class EventEntity: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var dueDate: Date
    var isComplete: Bool
    var userId: UUID

    init(id: UUID, title: String, createdAt: Date, dueDate: Date, isComplete: Bool, userId: UUID) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.isComplete = isComplete
        self.userId = userId
    }
}
