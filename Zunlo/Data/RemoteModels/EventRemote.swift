//
//  EventRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

struct EventRemote: Codable, Identifiable {
    var id: UUID?
    var user_id: UUID?
    let title: String
    let description: String?
    let start_datetime: Date
    let end_datetime: Date?
    let is_recurring: Bool
    let location: String?
    var created_at: Date?
    let updated_at: Date
}
