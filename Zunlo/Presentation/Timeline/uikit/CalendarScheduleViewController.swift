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
            self?.presentAddEvent()
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
    
    func scrollTo(date: Date, animated: Bool = false) {
        let today = date.startOfDay
        let todayItem = CalendarItem.day(today)

        let snapshot = dataSource.snapshot()
        if let itemIndex = snapshot.itemIdentifiers(inSection: 0).firstIndex(of: todayItem) {
            let indexPath = IndexPath(item: itemIndex, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
        } else {
            print("cell for \(date) not found in snapshot")
        }
    }
    
    @objc private func presentAddEvent() {
        let vm = AddEditEventViewModel(mode: .add, repository: viewModel.repository)
        let addView = AddEditEventView(viewModel: vm)
        let host = UIHostingController(rootView: addView)
        host.modalPresentationStyle = .formSheet
        present(host, animated: true)
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
                let image = self.viewModel.monthHeaderImageName(for: monthDate)
                cell.configure(title: title, imageName: image)
                return cell

            case .day(let dayDate):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DayEventCell", for: indexPath) as! DayEventCell
                let monthDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: dayDate))!
                let events = self.viewModel.occurrencesByMonthAndDay[monthDate]?[dayDate] ?? []
                cell.configure(with: dayDate, events: events)
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
