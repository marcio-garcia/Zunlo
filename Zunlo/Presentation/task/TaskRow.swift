//
//  TaskRow.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

struct TaskRow: View {
    var task: UserTask
    var onToggle: () -> Void
    var onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? Color.theme.accent : .gray)
                    .imageScale(.large)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .themedBody()
                    .strikethrough(task.isCompleted, color: .gray)
                    .foregroundColor(task.isCompleted ? .gray : .primary)

                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .themedCallout()
                        .strikethrough(task.isCompleted, color: .gray)
                        .foregroundColor(task.isCompleted ? .gray : .primary)
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
                    Text(due.formattedDate(dateFormat: .regular))
                        .themedCaption()
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

