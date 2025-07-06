//
//  EventOccurrence.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

struct EventOccurrence: Identifiable, Hashable {
    let id: UUID         // For recurring: master event ID + date can be composed as needed
    let eventId: UUID
    let title: String
    let description: String?
    let location: String?
    let startDate: Date
    let endDate: Date?
    let originalDate: Date
    let isOverride: Bool
    let isCancelled: Bool
}
