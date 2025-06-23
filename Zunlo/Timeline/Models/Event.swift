//
//  Event.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation
import SwiftData

@Model
class Event: Identifiable {
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
