//
//  Mapping+Events.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

extension Event {
    func toEventEntity() -> EventEntity {
        return EventEntity(id: id, title: title, createdAt: createdAt, dueDate: dueDate, isComplete: isComplete, userId: userId)
    }
}
