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
            switch viewModel.state {
            case .loaded:
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.occurrencesByMonthAndDay.keys.sorted(), id: \.self) { monthDate in
                            let monthName = monthDate.formattedDate(dateFormat: "LLLL")
                            let imageName = viewModel.monthHeaderImageName(for: monthDate)
                            let daysDict = viewModel.occurrencesByMonthAndDay[monthDate] ?? [:]

                            CartoonImageHeader(title: monthName, imageName: imageName)
                                .frame(maxWidth: .infinity)
                            
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(daysDict.keys.sorted(), id: \.self) { day in
                                    let occurrences = daysDict[day] ?? []
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(day.formattedDate(dateFormat: "E d"))
                                            .font(.headline)
                                            .padding(.leading, 16)
                                            .padding(.top, 8)
                                            .padding(.bottom, 4)
                                        ForEach(occurrences) { occurrence in
                                            EventRow(
                                                occurrence: occurrence,
                                                onEdit: { viewModel.handleEdit(occurrence: occurrence) },
                                                onDelete: { viewModel.handleDelete(occurrence: occurrence) }
                                            )
                                        }
                                    }
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 10)
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
            case .loading:
                ProgressView("Loading...")
            case .empty:
                EmptyScheduleView {
                    viewModel.showAddSheet = true
                }
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.eventOccurrences.isEmpty)
            case .error(let message):
                Text(message)
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
