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
    
    var position: Int = 0
    var total: Int = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

//    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
//        // Return desired height for events (could be dynamic based on content)
//        return CGSize(width: targetSize.width, height: 60)
//    }
    
    private func setup() {
        
//        eventView.layer.cornerCurve = .continuous
//        eventView.clipsToBounds = true
        
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

    func configure(occ: EventOccurrence, position: Int, total: Int) {
        self.occ = occ
        eventView.configure(with: occ)
        self.position = position
        self.total = total
        
        if self.total > 1 {
            if self.position == 0 {
                eventView.roundedCorners = [.topLeft, .topRight]
                eventView.strokeEdges = [.top, .left, .right]
                
            } else if self.position == self.total - 1 {
                eventView.roundedCorners = [.bottomLeft, .bottomRight]
                eventView.strokeEdges = [.bottom, .left, .right]
            } else {
                eventView.roundedCorners = []
                eventView.strokeEdges = [.left, .right]
            }
        } else {
            eventView.roundedCorners = [.allCorners]
            eventView.strokeEdges = [.all]
        }
    }
    
    @objc func viewTapped(_ sender: UIControl) {
        guard let occ else { return }
        onTap?(occ)
    }
}
