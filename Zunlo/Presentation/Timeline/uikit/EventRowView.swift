//
//  EventRowView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import UIKit
import SwiftUI

class EventRowView: UIView {
    private let card = RoundedStrokeView()
    private let colorIndicator = UIView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let overrideIcon = UIImageView()
    private let contentStackView = UIStackView()
    
    private var occurrence: EventOccurrence?
    
    var roundedCorners: UIRectCorner {
        get { return card.corners }
        set { card.corners = newValue }
    }
    
    var strokeEdges: UIRectEdge {
        get { return card.strokedEdges }
        set { card.strokedEdges = newValue }
    }
    
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
        roundedCorners = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        card.cornerRadius = 8
        card.borderWidth = 2
        card.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
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
        contentStackView.spacing = 12
        
        contentStackView.addArrangedSubview(colorIndicator)
        contentStackView.addArrangedSubview(textStack)
        contentStackView.addArrangedSubview(UIView())
        contentStackView.addArrangedSubview(overrideIcon)
        
        addSubview(card)
        addSubview(contentStackView)
    }

    private func setupConstraints() {
        card.translatesAutoresizingMaskIntoConstraints = false
        colorIndicator.translatesAutoresizingMaskIntoConstraints = false
        overrideIcon.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            
            colorIndicator.widthAnchor.constraint(equalToConstant: 6),
            colorIndicator.heightAnchor.constraint(equalTo: contentStackView.heightAnchor),
            
            overrideIcon.widthAnchor.constraint(equalToConstant: 16),
            overrideIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupTheme() {
        backgroundColor = .clear
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
        let color = UIColor(Color(hex: hex)!)
        colorIndicator.backgroundColor = color
        overrideIcon.isHidden = !occurrence.isOverride
        
        card.borderColor = UIColor(Color.theme.disabled)
        card.fillColor = color.withAlphaComponent(0.3)
    }
}
