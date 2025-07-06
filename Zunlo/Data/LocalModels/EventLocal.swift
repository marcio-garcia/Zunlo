//
//  EventLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation
import SwiftData

@Model
final class EventLocal {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var title: String
    var descriptionText: String?
    var startDate: Date
    var endDate: Date?
    var isRecurring: Bool
    var location: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        userId: UUID?,
        title: String,
        descriptionText: String?,
        startDate: Date,
        endDate: Date?,
        isRecurring: Bool,
        location: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
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
