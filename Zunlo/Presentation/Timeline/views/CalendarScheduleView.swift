//
//  CalendarScheduleView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/1/25.
//

import SwiftUI

struct CalendarScheduleView: View {
    @EnvironmentObject var repository: EventRepository

    @State private var showAddSheet = false
    @State private var editMode: AddEditEventViewModel.Mode?
    @State private var showEditSheet = false

    private var visibleRange: ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.date(byAdding: .month, value: -6, to: Date())!
        let end = cal.date(byAdding: .month, value: 6, to: Date())!
        return start...end
    }

    var body: some View {
        NavigationStack {
            if repository.eventOccurrences.isEmpty {
                EmptyScheduleView {
                    showAddSheet = true
                }
                .transition(.opacity)
                .animation(.easeInOut, value: repository.eventOccurrences.isEmpty)
            } else {
                List {
                    ForEach(daysWithOccurrences, id: \.self) { date in
                        Section(header: Text(date, style: .date)) {
                            ForEach(occurrences(on: date)) { occurrence in
                                EventRow(
                                    occurrence: occurrence,
                                    onEdit: { handleEdit(occurrence: occurrence) },
                                    onDelete: { handleDelete(occurrence: occurrence) }
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Schedule")
        
        // ADD/NEW SHEET
        .sheet(isPresented: $showAddSheet) {
            AddEditEventView(
                viewModel: AddEditEventViewModel(
                    mode: .add,
                    repository: repository
                )
            )
        }
        // EDIT SHEET (all possible edit flows, managed by editMode)
        .sheet(item: $editMode) { mode in
            AddEditEventView(
                viewModel: AddEditEventViewModel(
                    mode: mode,
                    repository: repository
                )
            )
        }
        .task {
            await repository.fetchAll(in: visibleRange)
        }
    }

    // MARK: - Helpers

    var daysWithOccurrences: [Date] {
        let days = Set(repository.eventOccurrences.map { $0.startDate.startOfDay })
        return Array(days).sorted()
    }

    func occurrences(on date: Date) -> [EventOccurrence] {
        repository.eventOccurrences.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    func handleEdit(occurrence: EventOccurrence) {
        // Get parent event and recurrence rule if needed
        if occurrence.isOverride {
            if let override = repository.eventOverrides.first(where: { $0.id == occurrence.id }) {
                editMode = .editOverride(override: override)
            }
        } else if let parent = repository.events.first(where: { $0.id == occurrence.eventId }) {
            let rule = repository.recurrenceRules.first(where: { $0.eventId == parent.id })
            if parent.isRecurring {
                // Prompt: Edit only this, or all?
                showEditChoiceDialog(for: occurrence, parentEvent: parent, rule: rule)
            } else {
                editMode = .editAll(event: parent, recurrenceRule: nil)
            }
        }
    }

    func showEditChoiceDialog(for occurrence: EventOccurrence, parentEvent: Event, rule: RecurrenceRule?) {
        // Simple action sheet (confirmationDialog in SwiftUI) for user choice
        let occurrenceDate = occurrence.startDate
        let dialog = UIAlertController(title: "Edit Recurring Event", message: nil, preferredStyle: .actionSheet)
        dialog.addAction(UIAlertAction(title: "Edit only this occurrence", style: .default) { _ in
            editMode = .editSingle(parentEvent: parentEvent, recurrenceRule: rule, occurrenceDate: occurrenceDate)
        })
        dialog.addAction(UIAlertAction(title: "Edit all occurrences", style: .default) { _ in
            editMode = .editAll(event: parentEvent, recurrenceRule: rule)
        })
        dialog.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        // Present dialog
        UIApplication.shared.windows.first?.rootViewController?.present(dialog, animated: true)
    }

    func handleDelete(occurrence: EventOccurrence) {
        // TODO: Implement delete/cancel logic (single/cascade, confirmation, etc.)
    }
}
