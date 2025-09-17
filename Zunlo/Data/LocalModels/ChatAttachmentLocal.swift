//
//  ChatAttachmentLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/17/25.
//

import Foundation
import RealmSwift

final class ChatAttachmentLocal: EmbeddedObject {
    @Persisted var id: UUID
    @Persisted var mime: String
    @Persisted var schema: String?
    @Persisted var filename: String?
    @Persisted var dataBase64: String
    
    convenience init(domain: ChatAttachment) {
        self.init()
        self.id = domain.id
        self.mime = domain.mime
        self.schema = domain.schema
        self.filename = domain.filename
        self.dataBase64 = domain.dataBase64
    }
}
