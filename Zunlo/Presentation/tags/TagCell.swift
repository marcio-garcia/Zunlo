//
//  TagCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import UIKit
import SwiftUI

class TagCell: UICollectionViewCell {
    static let reuseIdentifier = "TagCell"

    private let label = UILabel()
    private let deleteButton = UIButton(type: .custom)
    private var onDelete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerRadius = 15
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .clear

        label.font = AppFontStyle.caption.uiFont()
        label.textColor = UIColor(Color.theme.text)

        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = UIColor(Color.theme.disabled)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, deleteButton])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center

        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
//            contentView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let size = contentView.systemLayoutSizeFitting(layoutAttributes.size)
        attributes.frame.size = CGSize(width: size.width, height: 32) // fixed height
        return attributes
    }
    
    func configure(
        with tag: Tag,
        showDelete: Bool,
        onDelete: @escaping () -> Void
    ) {
        label.text = tag.text
        self.onDelete = onDelete
        deleteButton.isHidden = !showDelete
        contentView.backgroundColor = tag.selected ? UIColor(Color.theme.accent) : UIColor(tag.color)
        label.textColor = tag.selected ? .white : UIColor(Color.theme.text)
    }
    
    @objc private func deleteTapped() {
        onDelete?()
    }
}
