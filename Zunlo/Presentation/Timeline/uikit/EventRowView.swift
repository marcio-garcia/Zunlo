//
//  EventRowView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import UIKit
import SwiftUI

class EventRowView: UIControl {
    private let colorIndicator = UIView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let overrideIcon = UIImageView()
    private let contentStackView = UIStackView()
    
    private var occurrence: EventOccurrence?

    init() {
        super.init(frame: .zero)
        setup()
        setupConstraints()
        setupTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    private func setup() {
        colorIndicator.layer.cornerRadius = 3
        
        titleLabel.font = AppFontStyle.heading.uiFont()
        titleLabel.numberOfLines = 1

        timeLabel.font = AppFontStyle.footnote.uiFont()

        overrideIcon.image = UIImage(systemName: "pencil")
        overrideIcon.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, timeLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.spacing = 10
        
        contentStackView.addArrangedSubview(colorIndicator)
        contentStackView.addArrangedSubview(textStack)
        contentStackView.addArrangedSubview(UIView())
        contentStackView.addArrangedSubview(overrideIcon)
        
        addSubview(contentStackView)
    }

    private func setupConstraints() {
        colorIndicator.translatesAutoresizingMaskIntoConstraints = false
        overrideIcon.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            
            colorIndicator.widthAnchor.constraint(equalToConstant: 6),
            colorIndicator.heightAnchor.constraint(equalTo: contentStackView.heightAnchor),
            
            overrideIcon.widthAnchor.constraint(equalToConstant: 16),
            overrideIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupTheme() {
        colorIndicator.backgroundColor = .gray
        titleLabel.textColor = UIColor(Color.theme.text)
        timeLabel.textColor = UIColor(Color.theme.secondaryText)
        overrideIcon.tintColor = UIColor(Color.theme.accent)
    }
    
    func configure(with occurrence: EventOccurrence) {
        self.occurrence = occurrence
        titleLabel.text = occurrence.title
        
        if occurrence.isFakeOccForEmptyToday {
            timeLabel.text = nil
        } else {
            let start = occurrence.startDate.formattedDate(dateFormat: .time)
            if let endDate = occurrence.endDate {
                let end = endDate.formattedDate(dateFormat: .time)
                timeLabel.text = "\(start) - \(end)"
            } else {
                timeLabel.text = start
            }
        }

        let hex = occurrence.isFakeOccForEmptyToday ? "#E0E0E0" : occurrence.color.rawValue
        colorIndicator.backgroundColor = UIColor(Color(hex: hex)!)

        overrideIcon.isHidden = !occurrence.isOverride
    }

//    override var isHighlighted: Bool {
//        didSet {
//            backgroundColor = isHighlighted ? UIColor.systemGray5 : .clear
//        }
//    }
}
