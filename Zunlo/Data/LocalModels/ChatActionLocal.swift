//
//  ChatActionLocal.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/17/25.
//

import Foundation
import RealmSwift

final class ChatActionLocal: EmbeddedObject {
    @Persisted var typeRaw: String   // "copyText" | "copyAttachment" | "sendAttachmentToAI" | "disambiguateIntent"
    @Persisted var attachmentId: UUID?
    @Persisted var intentAlternatives: String? // comma-separated intent alternatives for disambiguation
    
    convenience init(from a: ChatMessageAction) {
        self.init()
        switch a {
        case .copyText:
            self.typeRaw = "copyText"
            self.attachmentId = nil
            self.intentAlternatives = nil
        case .copyAttachment(let id):
            self.typeRaw = "copyAttachment"
            self.attachmentId = id
            self.intentAlternatives = nil
        case .sendAttachmentToAI(let id):
            self.typeRaw = "sendAttachmentToAI"
            self.attachmentId = id
            self.intentAlternatives = nil
        case .disambiguateIntent(let alternatives):
            self.typeRaw = "disambiguateIntent"
            self.attachmentId = nil
            self.intentAlternatives = alternatives.joined(separator: ",")
        }
    }
}
