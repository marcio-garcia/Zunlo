//
//  User.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import Foundation

struct User: Codable, Sendable, Equatable {
    let id: UUID
    let email: String?
    let isAnonymous: Bool
}
