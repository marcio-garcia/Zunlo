//
//  ChatMessageActionAlternative.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/17/25.
//

import Foundation
import SmartParseKit

struct ChatMessageActionAlternative: Identifiable, Equatable, Hashable {
    var id: UUID
    var parseResultId: UUID
    var intentOption: Intent
    var editEventMode: AddEditEventViewMode?
    var label: AttributedString

    init(id: UUID, parseResultId: UUID, intentOption: Intent, editEventMode: AddEditEventViewMode?, label: AttributedString) {
        self.id = id
        self.parseResultId = parseResultId
        self.intentOption = intentOption
        self.editEventMode = editEventMode
        self.label = label
    }
    
    init(label: AttributedString) {
        self.id = UUID()
        self.parseResultId = UUID()
        self.intentOption = .unknown
        self.editEventMode = nil
        self.label = label
    }
}
