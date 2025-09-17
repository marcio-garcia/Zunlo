//
//  ChatMessageActionAlternative.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/17/25.
//

import Foundation
import SmartParseKit

public struct ChatMessageActionAlternative: Identifiable, Equatable, Hashable {
    public var id: UUID
    public var parseResultId: UUID
    public var intentOption: Intent
    public var label: String

    public init(id: UUID, parseResultId: UUID, intentOption: Intent, label: String) {
        self.id = id
        self.parseResultId = parseResultId
        self.intentOption = intentOption
        self.label = label
    }
    
    init(label: String) {
        self.id = UUID()
        self.parseResultId = UUID()
        self.intentOption = .unknown
        self.label = label
    }
}
