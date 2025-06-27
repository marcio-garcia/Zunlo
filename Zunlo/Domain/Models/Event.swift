//
//  Event.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/26/25.
//

import Foundation

struct Event: Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var title: String
    var createdAt: Date
    var dueDate: Date
    var isComplete: Bool
    
    static var empty: Event {
        return Event(id: UUID(), userId: UUID(), title: "", createdAt: Date(), dueDate: Date(), isComplete: false)
    }
}
