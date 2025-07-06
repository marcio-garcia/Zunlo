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
    let onEditAll: () -> Void

    var body: some View {
        VStack {
            Text("Edit recurring event")
            Button("Edit only this occurrence", action: onEditSingle)
            Button("Edit all events", action: onEditAll)
            Button("Cancel", role: .cancel) {}
        }
        .padding()
    }
}
