//
//  MonthHeaderCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import UIKit

class MonthHeaderCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .label

        imageView.contentMode = .scaleAspectFill
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.clipsToBounds = true

        addSubview(imageView)
        addSubview(label)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: widthAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 120),
//            imageView.heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.61017),

            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 30)
        ])
    }

    func configure(title: String, imageName: String) {
        label.text = title
        imageView.image = UIImage(named: imageName) ?? UIImage(systemName: "calendar")
    }
}
