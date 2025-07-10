//
//  EventColor.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/9/25.
//

import RealmSwift

enum EventColor: String, PersistableEnum, CaseIterable, Codable {
    case yellow = "#FFD966"
    case blue = "#AEEAF9"
    case green = "#F6B9C1"
    case pink = "#D1F7C4"
    case purple = "#D6C3FF"
}
