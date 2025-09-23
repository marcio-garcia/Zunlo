//
//  ChatMessageActionAlternative.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/17/25.
//

import Foundation
import SwiftUI
import SmartParseKit

struct ChatMessageActionAlternative: Identifiable, Equatable, Hashable {
    var id: UUID
    var commandContextId: UUID
    var intentOption: Intent
    var editEventMode: AddEditEventViewMode?
    var label: AttributedString
    var eventOccurrence: EventOccurrence?  // Store the full occurrence for recurring events
    var taskId: UUID?  // Store task ID for task-related actions

    init(id: UUID, commandContextId: UUID, intentOption: Intent, editEventMode: AddEditEventViewMode?, label: AttributedString, eventOccurrence: EventOccurrence? = nil, taskId: UUID? = nil) {
        self.id = id
        self.commandContextId = commandContextId
        self.intentOption = intentOption
        self.editEventMode = editEventMode
        self.label = label
        self.eventOccurrence = eventOccurrence
        self.taskId = taskId
    }

    init(label: AttributedString) {
        self.id = UUID()
        self.commandContextId = UUID()
        self.intentOption = .unknown
        self.editEventMode = nil
        self.label = label
        self.eventOccurrence = nil
        self.taskId = nil
    }
}
