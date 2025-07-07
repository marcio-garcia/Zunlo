//
//  Mapping+Events.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation

extension Event {
    init(remote: EventRemote) {
        guard let id = remote.id, let created_at = remote.created_at else {
            fatalError("Error mapping remote to local: invalid id or create_at.")
        }
        self.id = id
        self.userId = remote.user_id
        self.title = remote.title
        self.description = remote.description
        self.startDate = remote.start_datetime
        self.endDate = remote.end_datetime
        self.isRecurring = remote.is_recurring
        self.location = remote.location
        self.createdAt = created_at
        self.updatedAt = remote.updated_at
    }

    init(local: EventLocal) {
        self.id = local.id
        self.userId = local.userId
        self.title = local.title
        self.description = local.descriptionText
        self.startDate = local.startDate
        self.endDate = local.endDate
        self.isRecurring = local.isRecurring
        self.location = local.location
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
    }
}

extension EventRemote {
    init(domain: Event) {
        self.id = domain.id
        self.user_id = domain.userId
        self.title = domain.title
        self.description = domain.description
        self.start_datetime = domain.startDate
        self.end_datetime = domain.endDate
        self.is_recurring = domain.isRecurring
        self.location = domain.location
        self.created_at = domain.createdAt
        self.updated_at = domain.updatedAt
    }
}

extension EventLocal {
    convenience init(domain: Event) {
        guard let domainId = domain.id else {
            fatalError("Domain is must not be nil!")
        }
        self.init(
            id: domainId,
            userId: domain.userId,
            title: domain.title,
            descriptionText: domain.description,
            startDate: domain.startDate,
            endDate: domain.endDate,
            isRecurring: domain.isRecurring,
            location: domain.location,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt
        )
    }
    
    convenience init(remote: EventRemote) {
        guard let id = remote.id, let created_at = remote.created_at else {
            fatalError("Error mapping remote to local: invalid id or create_at.")
        }
        self.init(
            id: id,
            userId: remote.user_id,
            title: remote.title,
            descriptionText: remote.description,
            startDate: remote.start_datetime,
            endDate: remote.end_datetime,
            isRecurring: remote.is_recurring,
            location: remote.location,
            createdAt: created_at,
            updatedAt: remote.updated_at
        )
    }
    
    func getUpdateFields(_ event: EventRemote) {
        self.title = event.title
        self.descriptionText = event.description
        self.startDate = event.start_datetime
        self.endDate = event.end_datetime
        self.location = event.location
        self.isRecurring = event.is_recurring
        self.updatedAt = event.updated_at
    }
}
