//
//  TagCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import UIKit

class TagCell: UICollectionViewCell {
    static let reuseIdentifier = "TagCell"

    private let label = UILabel()
    private let deleteButton = UIButton(type: .custom)
    private var onDelete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerRadius = 15
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .systemGray5

        label.font = AppFontStyle.caption.uiFont()
        label.textColor = .label

        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = .gray
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
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            contentView.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        with tag: Tag,
        showDelete: Bool,
        onDelete: @escaping () -> Void
    ) {
        label.text = tag.text
        self.onDelete = onDelete
        deleteButton.isHidden = !showDelete
        contentView.backgroundColor = tag.selected ? UIColor.systemBlue : UIColor(tag.color)
        label.textColor = tag.selected ? .white : .label
    }
    
    @objc private func deleteTapped() {
        onDelete?()
    }
}
