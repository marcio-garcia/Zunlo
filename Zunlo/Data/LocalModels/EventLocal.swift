//
//  EventLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation
import RealmSwift

class EventLocal: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var userId: UUID?
    @Persisted var title: String = ""
    @Persisted var descriptionText: String?
    @Persisted var startDate: Date = Date()
    @Persisted var endDate: Date?
    @Persisted var isRecurring: Bool = false
    @Persisted var location: String?
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
    
    convenience init(
        id: UUID,
        userId: UUID? = nil,
        title: String = "",
        descriptionText: String? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        isRecurring: Bool = false,
        location: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init() // <-- MUST call the default init
        self.id = id
        self.userId = userId
        self.title = title
        self.descriptionText = descriptionText
        self.startDate = startDate
        self.endDate = endDate
        self.isRecurring = isRecurring
        self.location = location
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
