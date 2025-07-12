//
//  ChatMessage.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let userId: UUID?
    let message: String
    let createdAt: Date
    let isFromUser: Bool

    init(id: UUID, userId: UUID? = nil, message: String, createdAt: Date, isFromUser: Bool) {
        self.id = id
        self.userId = userId
        self.message = message
        self.createdAt = createdAt
        self.isFromUser = isFromUser
    }
    
    init(local: ChatMessageLocal) {
        self.id = local.id
        self.userId = local.userId
        self.message = local.message
        self.createdAt = local.createdAt
        self.isFromUser = local.isFromUser
    }
}
