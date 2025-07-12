//
//  ChatMessageLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation
import RealmSwift

class ChatMessageLocal: Object {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var userId: UUID?
    @Persisted var message: String = ""
    @Persisted var createdAt: Date = Date()
    @Persisted var isFromUser: Bool = false

    convenience init(id: UUID = UUID(), userId: UUID?, message: String, createdAt: Date = Date(), isFromUser: Bool) {
        self.init()
        self.id = id
        self.userId = userId
        self.message = message
        self.createdAt = createdAt
        self.isFromUser = isFromUser
    }
}
