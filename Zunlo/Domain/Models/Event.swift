//
//  Event.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/26/25.
//

import Foundation

struct Event: Identifiable, Codable, Hashable {
    let id: UUID?
    let userId: UUID?
    let title: String
    let description: String?
    let startDate: Date
    let endDate: Date?
    let isRecurring: Bool
    let location: String?
    let createdAt: Date
    let updatedAt: Date
}
