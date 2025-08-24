//
//  MonthHeaderCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import UIKit
import SwiftUI
import GlowUI

class MonthHeaderCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let monthLabel = UILabel()
    private let yearLabel = UILabel()
    private let borderView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

//    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
//        // Return desired height for month headers
//        return CGSize(width: targetSize.width, height: 100)
//    }
    
    private func setup() {
        borderView.layer.cornerRadius = 8
        borderView.layer.borderWidth = 2

        monthLabel.font = AppFontStyle.title.uiFont()
        yearLabel.font = AppFontStyle.heading.uiFont()
        
        imageView.contentMode = .scaleAspectFill
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true

        addSubview(imageView)
        addSubview(monthLabel)
        addSubview(yearLabel)
        addSubview(borderView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        monthLabel.translatesAutoresizingMaskIntoConstraints = false
        yearLabel.translatesAutoresizingMaskIntoConstraints = false
        borderView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 50),
            
            borderView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            borderView.topAnchor.constraint(equalTo: imageView.topAnchor),
            borderView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            
            monthLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 20),
            monthLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            
            yearLabel.leadingAnchor.constraint(equalTo: monthLabel.trailingAnchor, constant: 4),
            yearLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor, constant: 3)
        ])
    }
    
    private func setupTheme() {
        backgroundColor = .clear
        borderView.backgroundColor = .clear
        borderView.layer.borderColor = UIColor(Color.theme.disabled).cgColor
        monthLabel.textColor = UIColor(Color.theme.text)
        yearLabel.textColor = UIColor(Color.theme.secondaryText)
        
    }

    func configure(title: String, subtitle: String, imageName: String) {
        monthLabel.text = title
        imageView.image = UIImage(named: imageName) ?? UIImage(systemName: "calendar")
        imageView.alpha = 0.4
        yearLabel.text = subtitle
    }
}
