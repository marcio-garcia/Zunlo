//
//  CalendarScheduleView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/1/25.
//

import SwiftUI

struct CalendarScheduleView: View {
    @StateObject var viewModel: CalendarScheduleViewModel
    
    init(repository: EventRepository) {
        _viewModel = StateObject(wrappedValue: CalendarScheduleViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationStack {
            if viewModel.eventOccurrences.isEmpty {
                EmptyScheduleView {
                    viewModel.showAddSheet = true
                }
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.eventOccurrences.isEmpty)
            } else {
                List {
                    ForEach(viewModel.occurrencesByMonthAndDay.keys.sorted(), id: \.self) { monthDate in
                        Section(header: Text(monthDate.formattedDate(dateFormat: "LLLL yyyy"))) {
                            let daysDict = viewModel.occurrencesByMonthAndDay[monthDate] ?? [:]
                            ForEach(daysDict.keys.sorted(), id: \.self) { day in
                                Section(header: Text(day.formattedDate(dateFormat: "E d"))) {
                                    ForEach(daysDict[day] ?? []) { occurrence in
                                        EventRow(
                                            occurrence: occurrence,
                                            onEdit: { viewModel.handleEdit(occurrence: occurrence) },
                                            onDelete: { viewModel.handleDelete(occurrence: occurrence) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.showAddSheet = true
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                    }
                }
            }
        }
        .navigationTitle("Schedule")
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddEditEventView(
                viewModel: AddEditEventViewModel(
                    mode: .add,
                    repository: viewModel.repository
                )
            )
        }
        .sheet(item: $viewModel.editMode) { mode in
            AddEditEventView(
                viewModel: AddEditEventViewModel(
                    mode: mode,
                    repository: viewModel.repository
                )
            )
        }
        .confirmationDialog(
            "Edit Recurring Event",
            isPresented: $viewModel.showEditChoiceDialog,
            titleVisibility: .visible
        ) {
            Button("Edit only this occurrence") {
                viewModel.selectEditOnlyThisOccurrence()
            }
            Button("Edit all occurrences") {
                viewModel.selectEditAllOccurrences()
            }
            Button("Cancel", role: .cancel) {
                viewModel.showEditChoiceDialog = false
            }
        }
        .task {
            await viewModel.fetchEvents()
        }
    }
}
