//
//  TagCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import UIKit

struct Tag: Identifiable, Equatable {
    let id: UUID
    var text: String
    var color: UIColor

    init(id: UUID = UUID(), text: String, color: UIColor = .systemGray5) {
        self.id = id
        self.text = text
        self.color = color
    }
}

class TagCell: UICollectionViewCell {
    static let reuseIdentifier = "TagCell"

    private let label = UILabel()
    private let deleteButton = UIButton(type: .custom)
    private var onDelete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerRadius = 16
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
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    @objc private func deleteTapped() {
        onDelete?()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with tag: Tag, onDelete: @escaping () -> Void) {
        label.text = tag.text
        contentView.backgroundColor = tag.color
        self.onDelete = onDelete
    }
}
