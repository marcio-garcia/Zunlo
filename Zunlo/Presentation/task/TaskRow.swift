//
//  TaskRow.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

struct TaskRow: View {
    var task: UserTask
    var chipType: TagChipView.ChipType = .large
    var onToggle: () -> Void
    var onTap: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? Color.theme.accent : .gray)
                        .imageScale(.large)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .themedSubtitle()
                        .strikethrough(task.isCompleted, color: .gray)
                        .foregroundColor(task.isCompleted ? .gray : .primary)
                    
                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .themedCallout()
                            .strikethrough(task.isCompleted, color: .gray)
                            .foregroundColor(task.isCompleted ? .gray : .primary)
                    }
                    
                    if !task.tags.isEmpty {
                        TagChipListView(
                            tags: Binding(get: { task.tags }, set: { newValue in }),
                            mode: .readonly(selectable: false),
                            chipType: chipType
                        )
                    }
                }
                
                Spacer()
                
                VStack(alignment: HorizontalAlignment.trailing) {
                    Text(task.priority.description.capitalized)
                        .themedCaption()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(task.priority.color)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                    
                    if let due = task.dueDate {
                        Text(due.formattedDate(dateFormat: .regular, timeZone: Calendar.appDefault.timeZone))
                            .themedCaption()
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

