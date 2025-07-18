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
            
            if let priority = task.priority {
                Text(priority.rawValue.capitalized)
                    .themedCaption()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor(priority))
                    .foregroundColor(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
    }

    private func priorityColor(_ priority: UserTaskPriority) -> Color {
        switch priority {
        case .high: return .red.opacity(0.3)
        case .medium: return .orange.opacity(0.3)
        case .low: return .blue.opacity(0.3)
        }
    }
}

