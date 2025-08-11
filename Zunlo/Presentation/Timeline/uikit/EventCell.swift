//
//  EventCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/10/25.
//

import UIKit
import SwiftUI

class EventCell: UICollectionViewCell {
    private let eventView = EventRowView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        // Return desired height for events (could be dynamic based on content)
        return CGSize(width: targetSize.width, height: 60)
    }
    
    private func setup() {
        addSubview(eventView)
        
        eventView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            eventView.leadingAnchor.constraint(equalTo: leadingAnchor),
            eventView.trailingAnchor.constraint(equalTo: trailingAnchor),
            eventView.topAnchor.constraint(equalTo: topAnchor),
            eventView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setupTheme() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    func configure(occ: EventOccurrence) {
        eventView.configure(with: occ)
    }
}
