//
//  DayEventCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import UIKit
import SwiftUI

class DayEventCell: UICollectionViewCell {
    private let containerView = UIView()
    private let dayLabel = UILabel()
    private let eventsStack = UIStackView()
    private let contentStackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        containerView.layer.cornerRadius = 8
        containerView.layer.borderWidth = 1

        dayLabel.font = AppFontStyle.strongBody.uiFont()

        eventsStack.axis = .vertical
        eventsStack.spacing = 4
        eventsStack.alignment = .fill

        contentStackView.axis = .vertical
        contentStackView.spacing = 8
        contentStackView.alignment = .fill
        contentStackView.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        contentStackView.isLayoutMarginsRelativeArrangement = true

        contentStackView.addArrangedSubview(dayLabel)
        contentStackView.addArrangedSubview(eventsStack)

        contentView.addSubview(containerView)
        containerView.addSubview(contentStackView)
        
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }

    private func setupTheme() {
        contentView.backgroundColor = .clear
        containerView.backgroundColor = UIColor(Color.theme.eventCellBackground)
        containerView.layer.borderColor = UIColor(Color.theme.lightBorder).cgColor
        dayLabel.textColor = UIColor(Color.theme.text)
    }
    
    func configure(with date: Date, events: [EventOccurrence]) {
        dayLabel.text = date.formattedDate(dateFormat: .weekAndDay)
        dayLabel.textColor = date.isSameDay(as: Date()) ? UIColor(Color.theme.accent) : UIColor(Color.theme.text)
        
        eventsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if events.isEmpty {
            let label = UILabel()
            label.text = "No events"
            label.font = AppFontStyle.footnote.uiFont()
            label.textColor = UIColor(Color.theme.secondaryText)
            eventsStack.addArrangedSubview(label)
        } else {
            for occ in events {
                let row = EventRowView()
                row.configure(with: occ)
                row.addTarget(self, action: #selector(eventTapped(_:)), for: .touchUpInside)
                row.tag = occ.id.hashValue // or use a map
                eventsStack.addArrangedSubview(row)
            }
        }
    }
    
    @objc private func eventTapped(_ sender: UIControl) {
        // You can use delegation or closure callbacks to notify parent
        print("Tapped event with tag:", sender.tag)
    }

}
