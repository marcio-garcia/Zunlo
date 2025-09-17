//
//  ChatAttachment.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/17/25.
//

import Foundation
import RealmSwift

public struct ChatAttachment: Identifiable, Equatable, Hashable, Codable {
    public let id: UUID
    public let mime: String            // e.g., "application/json"
    public let schema: String?         // e.g., "zunlo.agenda#1"
    public let filename: String?
    public let dataBase64: String      // store text JSON as utf8/base64
    
    static func json(schema: String, json: String, filename: String? = nil) -> ChatAttachment {
        ChatAttachment(id: UUID(), mime: "application/json", schema: schema, filename: filename ?? "payload.json", dataBase64: Data(json.utf8).base64EncodedString())
    }
    
    func decodedString() -> String? {
        Data(base64Encoded: dataBase64).flatMap { String(data: $0, encoding: .utf8) }
    }
}

extension ChatAttachment {
    init(local: ChatAttachmentLocal) {
        self.id = local.id
        self.mime = local.mime
        self.schema = local.schema
        self.filename = local.filename
        self.dataBase64 = local.dataBase64
    }
}
