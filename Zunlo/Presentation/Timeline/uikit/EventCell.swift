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
    var onTap: ((EventOccurrence?) -> Void)?
    var occ: EventOccurrence?
    
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
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        eventView.addGestureRecognizer(tap)
        
        contentView.addSubview(eventView)
        
        eventView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            eventView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            eventView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            eventView.topAnchor.constraint(equalTo: contentView.topAnchor),
            eventView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func setupTheme() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    func configure(occ: EventOccurrence) {
        self.occ = occ
        eventView.configure(with: occ)
    }
    
    @objc func viewTapped(_ sender: UIControl) {
        guard let occ else { return }
        onTap?(occ)
    }
}
