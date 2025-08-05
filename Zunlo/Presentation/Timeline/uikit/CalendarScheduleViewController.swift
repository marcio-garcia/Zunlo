//
//  CalendarScheduleViewController.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import UIKit
import Combine
import SwiftUI

struct EventSection {
    let monthDate: Date
    var dayGroups: [(date: Date, occurrences: [EventOccurrence])]
}

enum CalendarItem: Hashable {
    case monthHeader(Date)
    case day(Date)
}

class CalendarScheduleViewController: UIViewController {
    private let topBarView = CalendarTopBarView()
    private var collectionView: UICollectionView!
    
    private let viewModel: CalendarScheduleViewModel
    private var dataSource: UICollectionViewDiffableDataSource<Int, CalendarItem>!
    private var didScrollToToday = false
    
    init(viewModel: CalendarScheduleViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        viewModel.$occurrencesByMonthAndDay
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applySnapshot() }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupConstraints()
        setupTheme()
    }
    
    private func setupViews() {
        topBarView.configure(title: "Events", accentColor: UIColor(Color.theme.accent))
        topBarView.onTapClose = { [weak self] in
            self?.dismiss(animated: true)
        }
        topBarView.onTapToday = { [weak self] in
            self?.scrollTo(date: Date(), animated: true)
        }
        topBarView.onTapAdd = { [weak self] in
            self?.showAddEventView(mode: .add)
        }
        
        setupCollectionView()
        
        view.addSubview(topBarView)
        
        Task {
            await viewModel.fetchEvents()
        }
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
    
    func scrollTo(date: Date, animated: Bool = false, extraOffset: CGFloat = 56) {
        let targetDate = date.startOfDay
        let item = CalendarItem.day(targetDate)

        let snapshot = dataSource.snapshot()
        guard let itemIndex = snapshot.itemIdentifiers(inSection: 0).firstIndex(of: item) else {
            print("cell for \(date) not found in snapshot")
            return
        }

        let indexPath = IndexPath(item: itemIndex, section: 0)

        collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)

        // Adjust offset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0.35 : 0)) { [weak self] in
            guard let self = self else { return }

            var offset = self.collectionView.contentOffset
            offset.y -= extraOffset
            offset.y = max(-self.collectionView.adjustedContentInset.top, offset.y) // don’t scroll above content
            self.collectionView.setContentOffset(offset, animated: false)
        }
    }
    
    private func findOccurrence(startDate targetDate: Date) -> EventOccurrence? {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: targetDate))!
        let startOfDay = calendar.startOfDay(for: targetDate)

        if let dayDict = viewModel.occurrencesByMonthAndDay[startOfMonth],
           let occurrences = dayDict[startOfDay] {
            return occurrences.first(where: { $0.startDate == targetDate })
        }
        return nil
    }
}

extension CalendarScheduleViewController {
    func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, _ in
            self.layoutForSection()
        }
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.register(DayEventCell.self, forCellWithReuseIdentifier: "DayEventCell")
        collectionView.register(MonthHeaderCell.self, forCellWithReuseIdentifier: "MonthHeaderCell")

        view.addSubview(collectionView)

        configureDataSource()
    }

    func layoutForSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize:
            .init(widthDimension: .fractionalWidth(1.0),
                  heightDimension: .estimated(60))
        )

        let group = NSCollectionLayoutGroup.vertical(layoutSize:
            .init(widthDimension: .fractionalWidth(1.0),
                  heightDimension: .estimated(60)),
            subitems: [item]
        )

        return NSCollectionLayoutSection(group: group)
    }
}

extension CalendarScheduleViewController {
    func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, CalendarItem>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            guard let self = self else { return nil }

            switch item {
            case .monthHeader(let monthDate):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MonthHeaderCell", for: indexPath) as! MonthHeaderCell
                let title = monthDate.formattedDate(dateFormat: .monthName)
                let subtitle = monthDate.formattedDate(dateFormat: .year)
                let image = self.viewModel.monthHeaderImageName(for: monthDate)
                cell.configure(title: title, subtitle: subtitle, imageName: image)
                return cell

            case .day(let dayDate):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DayEventCell", for: indexPath) as! DayEventCell
                let monthDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: dayDate))!
                let events = self.viewModel.occurrencesByMonthAndDay[monthDate]?[dayDate] ?? []
                cell.configure(with: dayDate, events: events, viewModel: viewModel)
                cell.onTap = { occurrence in
                    guard let occurrence else { return }
                    self.viewModel.onEventEditTapped(occurrence) { mode, showDialog in
                        if showDialog {
                            self.showActionSheet()
                        } else {
                            guard let mode else { return }
                            self.showAddEventView(mode: mode)
                        }
                    }
                }
                return cell
            }
        }
    }

    func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, CalendarItem>()
        snapshot.appendSections([0])

        let keys = viewModel.occurrencesByMonthAndDay.keys.sorted()
        for monthDate in keys {
            snapshot.appendItems([.monthHeader(monthDate)])
            let days = viewModel.occurrencesByMonthAndDay[monthDate]?.keys.sorted() ?? []
            snapshot.appendItems(days.map { .day($0) })
        }

        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self else { return }
            if !keys.isEmpty {
                if self.didScrollToToday {
                    self.collectionView.delegate = nil
                    self.scrollTo(date: viewModel.itemDateToScrollTo)
                    self.collectionView.delegate = self
                    self.didScrollToToday = true
                } else {
                    self.collectionView.delegate = nil
                    self.scrollTo(date: Date())
                    self.collectionView.delegate = self
                    self.didScrollToToday = true
                }
            }
        }
    }
}

extension CalendarScheduleViewController: UICollectionViewDelegate {
    
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let offsetY = scrollView.contentOffset.y
        let thresholdTop = UIScreen.main.bounds.height * 2
        let thresholdBottom = scrollView.contentSize.height - scrollView.bounds.height - 1000

        if offsetY < thresholdTop {
            targetContentOffset.pointee = scrollView.contentOffset
            guard let date = dateOfExpansionTrigger(scrollView: scrollView) else { return }
            viewModel.checkTop(date: date)
        } else if offsetY > thresholdBottom {
            targetContentOffset.pointee = scrollView.contentOffset
            guard let date = dateOfExpansionTrigger(scrollView: scrollView) else { return }
            viewModel.checkBottom(date: date)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let thresholdTop = UIScreen.main.bounds.height * 2
        let thresholdBottom = scrollView.contentSize.height - scrollView.bounds.height - 1000

        if offsetY < thresholdTop {
            guard let date = dateOfExpansionTrigger(scrollView: scrollView) else { return }
            viewModel.checkTop(date: date)
        } else if offsetY > thresholdBottom {
            guard let date = dateOfExpansionTrigger(scrollView: scrollView) else { return }
            viewModel.checkBottom(date: date)
        }
    }
    
    private func dateOfExpansionTrigger(scrollView: UIScrollView) -> Date? {
        guard
            let collectionView = scrollView as? UICollectionView,
            let indexPath = collectionView.indexPathForItem(at: collectionView.contentOffset),
            let item = dataSource.itemIdentifier(for: indexPath)
        else { return nil }
        
        var date: Date
        
        switch item {
        case .monthHeader(let monthDate): date = monthDate
        case .day(let dayDate): date = dayDate
        }
        
        return date
    }
}

// MARK: Navigation

extension CalendarScheduleViewController {
    private func showAddEventView(mode: AddEditEventViewMode) {
        let vm = AddEditEventViewModel(mode: mode, repository: viewModel.repository)
        let addView = AddEditEventView(viewModel: vm) { [weak self] updatedEventStartDate in
            guard let self else { return }
            self.collectionView.reloadData()
            // TODO: Make the callback return the updatd event then update the model and apply to the dataSource
//            let occ = self.findOccurrence(startDate: updatedEventStartDate)
//           currentEvents[index] = updatedEvent
//           var snapshot = NSDiffableDataSourceSnapshot<Section, Event>()
//           snapshot.appendSections([.main]) // Adjust if using multiple sections
//           snapshot.appendItems(currentEvents, toSection: .main)
//           dataSource.apply(snapshot, animatingDifferences: true)
        }
        let host = UIHostingController(rootView: addView)
        host.modalPresentationStyle = .formSheet
        present(host, animated: true)
    }
    
    private func showActionSheet() {
        let sheet = UIAlertController(
            title: "Edit Recurring Event",
            message: nil,
            preferredStyle: .actionSheet
        )
        
        sheet.addAction(UIAlertAction(
            title: "Edit only this occurrence",
            style: .default,
            handler: { action in
                self.viewModel.eventEditHandler.selectEditOnlyThisOccurrence()
                guard let editMode = self.viewModel.eventEditHandler.editMode else { return }
                self.showAddEventView(mode: editMode)
            }))
        
        sheet.addAction(UIAlertAction(
            title: "Edit all occurrences",
            style: .default,
            handler: { action in
                self.viewModel.eventEditHandler.selectEditAllOccurrences()
                guard let editMode = self.viewModel.eventEditHandler.editMode else { return }
                self.showAddEventView(mode: editMode)
            }))
        
        sheet.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: { action in
                self.viewModel.eventEditHandler.showEditChoiceDialog = false
            }))
        present(sheet, animated: true)
    }
}
