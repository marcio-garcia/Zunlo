//
//  CalendarScheduleViewController.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import UIKit
import Combine
import SwiftUI

enum CalendarSection: Int, CaseIterable {
    case month
}

enum CalendarItem: Hashable {
    case month(Date)
    case day(Date)
    case event(_ event: EventOccurrence, _ position: Int, _ total: Int)
    
    // Automatically derived Equatable conformance (because all associated types are Equatable)
    static func ==(lhs: CalendarItem, rhs: CalendarItem) -> Bool {
        switch (lhs, rhs) {
        case (.month(let date1), .month(let date2)):
            return date1 == date2
        case (.day(let date1), .day(let date2)):
            return date1 == date2
        case (.event(let event1, _, _), .event(let event2, _, _)):
            return event1 == event2
        default:
            return false
        }
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .month(let date):
            hasher.combine(date)
        case .day(let date):
            hasher.combine(date)
        case .event(let event, _, _):
            hasher.combine(event.id)  // Using event ID to hash the event
        }
    }
}

class CalendarScheduleViewController: UIViewController {
    private let topBarView = CalendarTopBarView()
    private var collectionView: UICollectionView!
    
    private var dataSource: UICollectionViewDiffableDataSource<CalendarSection, CalendarItem>!
    private var didScrollToToday = false
    
    var viewModel: CalendarScheduleViewModel
    var nav: AppNav
    
    var onTapClose: (() -> Void)?
    
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: CalendarScheduleViewModel, nav: AppNav, onTapClose: (() -> Void)?) {
        self.viewModel = viewModel
        self.nav = nav
        self.onTapClose = onTapClose
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupConstraints()
        setupTheme()
        
        setupDataSource()
        
        viewModel.$eventOccurrences
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applySnapshot()
            }
            .store(in: &cancellables)
        
        Task {
            await viewModel.fetchEvents()
            await MainActor.run {
                self.scrollTo(date: Date(), animated: true)
            }
        }
    }
    
    private func setupViews() {
        topBarView.configure(
            title: String(localized: "Events"),
            accentColor: UIColor(Color.theme.accent)
        )
        topBarView.onTapClose = { [weak self] in
            self?.onTapClose?()
        }
        topBarView.onTapToday = { [weak self] in
            self?.scrollTo(date: Date(), animated: true)
        }
        topBarView.onTapAdd = { [weak self] in
            self?.showAddEventView(mode: .add)
        }
        
        setupCollectionView()
        
        view.addSubview(topBarView)
    }
    
    private func setupConstraints() {
        topBarView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topBarView.topAnchor.constraint(equalTo: view.topAnchor), // includes safe area internally
            topBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupTheme() {
        view.backgroundColor = UIColor(Color.theme.background)
    }
}

extension CalendarScheduleViewController {
    func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createCompositionalLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.register(DayEventCell.self, forCellWithReuseIdentifier: "DayEventCell")
        collectionView.register(MonthHeaderCell.self, forCellWithReuseIdentifier: "MonthHeaderCell")
        collectionView.register(EventCell.self, forCellWithReuseIdentifier: "EventCell")

        view.addSubview(collectionView)
    }

    func createMonthSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .estimated(50))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(50))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        
        group.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 10, trailing: 20)
        
        let section = NSCollectionLayoutSection(group: group)
        
        return section
    }

    func createDaySection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.8), heightDimension: .absolute(50))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(200))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        
        return section
    }

    func createEventSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.8), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(200))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        
        return section
    }

    func createCompositionalLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            switch sectionIndex {
            case 0:
                return self.createMonthSection()
//            case 1:
//                return self.createDaySection()
//            case 2:
//                return self.createEventSection()
            default:
                return nil
            }
        }
        
        return layout
    }
}

extension CalendarScheduleViewController {
    // MARK: - Diffable Data Source
    func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<CalendarSection, CalendarItem>(collectionView: collectionView) { (collectionView, indexPath, item) -> UICollectionViewCell? in
            switch item {
            case .month(let monthDate):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MonthHeaderCell", for: indexPath) as! MonthHeaderCell
                let title = monthDate.formattedDate(dateFormat: .monthName, locale: Locale(identifier: Locale.current.identifier))
                let subtitle = monthDate.formattedDate(dateFormat: .year)
                let image = self.viewModel.monthHeaderImageName(for: monthDate)
                cell.configure(title: title, subtitle: subtitle, imageName: image)
                return cell
            case .day(let dayDate):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DayEventCell", for: indexPath) as! DayEventCell
                cell.configure(with: dayDate, viewModel: self.viewModel)
                return cell
            case .event(let event, let position, let total):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EventCell", for: indexPath) as! EventCell
                cell.configure(occ: event, position: position, total: total)
                cell.onTap = { [weak self] occ in
                    guard let self, let occ else { return }
                    self.viewModel.onEventEditTapped(occ, completion: { mode, showDialog in
                        if showDialog {
                            self.showActionSheet()
                        } else {
                            guard let mode else { return }
                            self.showAddEventView(mode: mode)
                        }
                    })
                }
                return cell
            }
        }
    }
  
    func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<CalendarSection, CalendarItem>()
        
        snapshot.appendSections([.month])
        
        let groupedByMonth = groupEventsByMonth2(events: viewModel.eventOccurrences)
        
        let monthDates = groupedByMonth.keys.sorted()
        for monthDate in monthDates {
            // Add month header
            snapshot.appendItems([.month(monthDate)], toSection: .month)
            
            let groupedByDay = groupEventsByDay(events: groupedByMonth[monthDate]!)
            
            let dayDates = groupedByDay.keys.sorted()
            for day in dayDates {
                snapshot.appendItems([.day(day)], toSection: .month)
                
                let events = groupedByDay[day]!
                let sortedEvents = events.sorted { $0.startDate < $1.startDate }
                
                // Add events immediately after their day header
                var eventItems: [CalendarItem] = []
                for index in 0..<sortedEvents.count {
                    eventItems.append(
                        CalendarItem.event(sortedEvents[index], index, sortedEvents.count)
                    )
                }
                
                snapshot.appendItems(eventItems, toSection: .month)
            }
        }

        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    func groupEventsByMonth2(events: [EventOccurrence]) -> [Date: [EventOccurrence]] {
        let calendar = Calendar.appDefault
        
        let groupedByMonth = Dictionary(grouping: events) { (event: EventOccurrence) -> Date in
            // Get the start of the month (year and month)
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.startDate))!
        }
        return groupedByMonth
    }
        
//    func groupEventsByMonth(events: [EventOccurrence]) -> [CalendarItem] {
//        let calendar = Calendar.appDefault
//        var months: [CalendarItem] = []
//        
//        // Group events by month
//        let groupedByMonth = Dictionary(grouping: events) { (event: EventOccurrence) -> Date in
//            // Get the start of the month (year and month)
//            calendar.date(from: calendar.dateComponents([.year, .month], from: event.startDate))!
//        }
//        
//        let monthDates = groupedByMonth.keys.sorted()
//        for monthDate in monthDates {
//            // Group events in this month by day
//            let groupedByDay = groupEventsByDay(events: groupedByMonth[monthDate]!)
//            
//            // Append month as CalendarItem.month
//            months.append(.month(monthDate))
//            
//            // For each day in this month, append the CalendarItem.day
//            let dayDates = groupedByDay.keys.sorted()
//            for dayDate in dayDates {
//                months.append(.day(dayDate))
//                
//                // For each event on this day, append the CalendarItem.event
//                for event in groupedByDay[dayDate]! {
//                    months.append(.event(event))
//                }
//            }
//        }
//        
//        return months
//    }

    func groupEventsByDay(events: [EventOccurrence]) -> [Date: [EventOccurrence]] {
        let calendar = Calendar.appDefault
        let groupedByDay = Dictionary(grouping: events) { (event: EventOccurrence) -> Date in
            // Get the start of the day (ignoring time for grouping purposes)
            calendar.startOfDay(for: event.startDate)
        }
        return groupedByDay
    }
}

// MARK: - Scroll to Date Implementation
extension CalendarScheduleViewController {
    
    func scrollTo(date: Date, animated: Bool = false, extraOffset: CGFloat = 56) {
        let targetDate = Calendar.appDefault.startOfDay(for: date)
        let item = CalendarItem.day(targetDate)
        
        let snapshot = dataSource.snapshot()
        guard let itemIndex = snapshot.itemIdentifiers(inSection: .month).firstIndex(of: item) else {
            print("Day cell for \(date) not found in snapshot")
            return
        }
        
        let indexPath = IndexPath(item: itemIndex, section: 0)
        
        collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
        
        // Adjust offset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0.35 : 0)) { [weak self] in
            guard let self = self else { return }
            
            var offset = self.collectionView.contentOffset
            offset.y -= extraOffset
            offset.y = max(-self.collectionView.adjustedContentInset.top, offset.y) // don't scroll above content
            self.collectionView.setContentOffset(offset, animated: true)
        }
    }
}

extension CalendarScheduleViewController: UICollectionViewDelegate {
    
//    func scrollViewWillEndDragging(
//        _ scrollView: UIScrollView,
//        withVelocity velocity: CGPoint,
//        targetContentOffset: UnsafeMutablePointer<CGPoint>
//    ) {
//        let offsetY = scrollView.contentOffset.y
////        let thresholdTop = UIScreen.main.bounds.height * 2
//        let thresholdBottom = scrollView.contentSize.height - scrollView.bounds.height - 1000
//
//        // Commented out to remove the date range expasion for older dates
//        // because it is buggy
////        if offsetY < thresholdTop {
////            targetContentOffset.pointee = scrollView.contentOffset
////            guard let date = dateOfExpansionTrigger(scrollView: scrollView) else { return }
////            viewModel.checkTop(date: date)
////        } else
//        if offsetY > thresholdBottom {
//            targetContentOffset.pointee = scrollView.contentOffset
//            guard let date = dateOfExpansionTrigger(scrollView: scrollView) else { return }
//            viewModel.checkBottom(date: date)
//        }
//    }
    
//    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//        let offsetY = scrollView.contentOffset.y
////        let thresholdTop = UIScreen.main.bounds.height * 2
//        let thresholdBottom = scrollView.contentSize.height - scrollView.bounds.height - 1000
//
//        // Commented out to remove the date range expasion for older dates
//        // because it is buggy
////        if offsetY < thresholdTop {
////            guard let date = dateOfExpansionTrigger(scrollView: scrollView) else { return }
////            viewModel.checkTop(date: date)
////        } else
//        if offsetY > thresholdBottom {
//            guard let date = dateOfExpansionTrigger(scrollView: scrollView) else { return }
//            viewModel.checkBottom(date: date)
//        }
//    }
    
//    private func dateOfExpansionTrigger(scrollView: UIScrollView) -> Date? {
//        guard
//            let collectionView = scrollView as? UICollectionView,
//            let indexPath = collectionView.indexPathForItem(at: collectionView.contentOffset),
//            let item = dataSource.itemIdentifier(for: indexPath)
//        else { return nil }
//        
//        var date: Date
//        
//        switch item {
//        case .monthHeader(let monthDate): date = monthDate
//        case .day(let dayDate): date = dayDate
//        }
//        
//        return date
//    }
}

// MARK: Navigation

extension CalendarScheduleViewController {
    private func showAddEventView(mode: AddEditEventViewMode) {
        let vm = AddEditEventViewModel(
            userId: viewModel.userId,
            mode: mode,
            editor: EventEditor(repo: AppState.shared.eventRepository!)
        )
        let addView = AddEditEventView(
            viewModel: vm,
            onDismiss: { [weak self] in
                guard let self else { return }
                Task { await self.viewModel.fetchEvents() }
            })
            .environmentObject(nav)
    
        let host = UIHostingController(rootView: addView)
        host.modalPresentationStyle = .formSheet
        present(host, animated: true)
    }
    
    private func showActionSheet() {
        let sheet = UIAlertController(
            title: String(localized: "Edit Recurring Event"),
            message: nil,
            preferredStyle: .actionSheet
        )
        
        sheet.addAction(UIAlertAction(
            title: String(localized: "Edit only this occurrence"),
            style: .default,
            handler: { action in
                guard let editMode = self.viewModel.eventEditHandler.selectEditOnlyThisOccurrence() else { return }
                self.showAddEventView(mode: editMode)
            }))
        
        sheet.addAction(UIAlertAction(
            title: String(localized: "Edit this and future occurrences"),
            style: .default,
            handler: { action in
                guard let editMode = self.viewModel.eventEditHandler.selectEditFutureOccurrences() else { return }
                self.showAddEventView(mode: editMode)
            }))
        
        sheet.addAction(UIAlertAction(
            title: String(localized: "Edit all occurrences"),
            style: .default,
            handler: { action in
                guard let editMode = self.viewModel.eventEditHandler.selectEditAllOccurrences() else { return }
                self.showAddEventView(mode: editMode)
            }))
        
        sheet.addAction(UIAlertAction(
            title: String(localized: "Cancel"),
            style: .cancel,
            handler: { action in
                self.viewModel.eventEditHandler.showEditChoiceDialog = false
            }))
        present(sheet, animated: true)
    }
}
