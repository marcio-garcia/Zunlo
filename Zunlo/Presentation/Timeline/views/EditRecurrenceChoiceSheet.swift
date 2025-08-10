//
//  EditRecurrenceChoiceSheet.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import SwiftUI

struct EditRecurrenceChoiceSheet: View {
    let occurrence: EventOccurrence
    let onEditSingle: () -> Void
    let onEditThisFuture: () -> Void
    let onEditAll: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack {
            Text("Edit recurring event")
            Button("Edit only this occurrence", action: onEditSingle)
            Button("Edit this and future occurrences", action: onEditThisFuture)
            Button("Edit all occurrences", action: onEditAll)
            Button("Cancel", role: .cancel, action: onCancel)
        }
        .padding()
    }
}
