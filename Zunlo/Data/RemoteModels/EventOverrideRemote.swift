//
//  EventOverrideRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

struct EventOverrideRemote: Codable, Identifiable {
    var id: UUID?
    let event_id: UUID
    let occurrence_date: Date
    let overridden_title: String?
    let overridden_start_datetime: Date?
    let overridden_end_datetime: Date?
    let overridden_location: String?
    let is_cancelled: Bool
    let notes: String?
    let created_at: Date
    let updated_at: Date
}
