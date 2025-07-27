//
//  CalendarScheduleView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/1/25.
//

import SwiftUI

struct CalendarScheduleView: View {
    @StateObject var viewModel: CalendarScheduleViewModel
    let edgeExecutor = DebouncedExecutor(delay: 0.5)
    
    init(repository: EventRepository, locationService: LocationService) {
        _viewModel = StateObject(wrappedValue: CalendarScheduleViewModel(repository: repository,
                                                                         locationService: locationService))
    }
    
    private func isToday(date: Date) -> Bool {
        let today = Date()
        return date.isSameDay(as: today)
    }
    
    var body: some View {
        NavigationStack {
            switch viewModel.state {
            case .loaded(let referenceDate):
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.occurrencesByMonthAndDay.keys.sorted(), id: \.self) { monthDate in
                                let monthName = monthDate.formattedDate(dateFormat: .monthName)
                                let imageName = viewModel.monthHeaderImageName(for: monthDate)
                                let daysDict = viewModel.occurrencesByMonthAndDay[monthDate] ?? [:]
                                let sortedDays = daysDict.keys.sorted()
                                
                                CartoonImageHeader(title: monthName, imageName: imageName)
                                    .frame(maxWidth: .infinity)
                                
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(sortedDays, id: \.self) { day in
                                        let occurrences = daysDict[day] ?? []
                                        VStack(alignment: .leading, spacing: 0) {
                                            if occurrences.isEmpty {
                                                EventPlaceholderRow(date: day, onTap: {
                                                    viewModel.showAddSheet = true
                                                })
                                            } else {
                                                HStack {
                                                    Text(day.formattedDate(dateFormat: .weekAndDay))
                                                        .foregroundStyle(Color.theme.text)
                                                        .font(AppFontStyle.strongBody.font())
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 4)
                                                        .background(
                                                            isToday(date: day) ? Capsule().fill(Color.blue) : nil
                                                        )
                                                    Text(day.formattedDate(dateFormat: .year))
                                                        .foregroundStyle(Color.theme.text)
                                                        .font(AppFontStyle.caption.font())
                                                }
                                                .padding(.leading, 16)
                                                .padding(.top, isToday(date: day) ? 8 : 0)
                                                
                                                ForEach(occurrences) { occurrence in
                                                    EventRow(occurrence: occurrence, onTap: { viewModel.handleEdit(occurrence: occurrence) })
                                                }
                                            }
                                        }
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear.preference(
                                                    key: DayPositionPreferenceKey.self,
                                                    value: [day: geo.frame(in: .global).minY]
                                                )
                                            }
                                        )
                                        .background(Color.white)
                                        .cornerRadius(10)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 16)
                                        .id(day.startOfDay)
                                    }
                                }
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        edgeExecutor.cancelAll()
                                        proxy.scrollTo(referenceDate.startOfDay, anchor: .top)
                                    }
                                }
                            }
                        }
                        .scrollEdgeObserver(
                            onEdgeNearTop: {
                                edgeExecutor.execute(id: "top-edge-check") {
                                    viewModel.checkIfNearVisibleEdge(viewModel.visibleRange.lowerBound)
                                }
                            },
                            onEdgeNearBottom: {
                                edgeExecutor.execute(id: "bottom-edge-check") {
                                    viewModel.checkIfNearVisibleEdge(viewModel.visibleRange.upperBound)
                                }
                            },
                            currentTopDayChanged: { day in
                                viewModel.currentTopVisibleDay = day
                            }
                        )
                        .defaultBackground()
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Events")
                                .themedSubtitle()
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            HStack(spacing: 12) {
                                Button {
                                    DispatchQueue.main.async {
                                        withAnimation {
                                            proxy.scrollTo(Date().startOfDay, anchor: .top)
                                        }
                                    }
                                } label: {
                                    Label("Today", systemImage: "calendar.badge.clock")
                                }
                                
                                Button {
                                    viewModel.showAddSheet = true
                                } label: {
                                    Label("Add", systemImage: "plus")
                                }
                            }
                        }
                    }
                }
            case .loading:
                VStack {
                    ProgressView("Loading...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .defaultBackground()
            case .empty:
                VStack {
                    EmptyScheduleView {
                        viewModel.showAddSheet = true
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .defaultBackground()
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.eventOccurrences.isEmpty)
            case .error(let message):
                VStack {
                    Text(message)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .defaultBackground()
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
