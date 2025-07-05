//
//  EventOverride.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

struct EventOverride: Identifiable, Codable, Hashable {
    let id: UUID
    let eventId: UUID
    let occurrenceDate: Date
    let overriddenTitle: String?
    let overriddenStartDate: Date?
    let overriddenEndDate: Date?
    let overriddenLocation: String?
    let isCancelled: Bool
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}
