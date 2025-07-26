//
//  TagCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import UIKit

struct Tag: Identifiable, Equatable, Hashable {
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
    private var onTap: ((Tag) -> Void)?
    
    private var tagObject: Tag?
    private var isTagHighlighted: Bool = false
    private var color: UIColor {
        return isTagHighlighted ? .orange : .systemGray5
    }

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
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        addGestureRecognizer(tap)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        with tag: Tag,
        showDelete: Bool,
        onTap: @escaping (Tag) -> Void,
        onDelete: @escaping () -> Void
    ) {
        tagObject = tag
        label.text = tag.text
        self.onTap = onTap
        self.onDelete = onDelete
        deleteButton.isHidden = !showDelete
    }
    
    func setBackgroundColor(color: UIColor) {
        contentView.backgroundColor = color
    }
    
    @objc private func deleteTapped() {
        onDelete?()
    }
    
    @objc private func viewTapped() {
        guard let tag = tagObject else { return }
        isTagHighlighted.toggle()
        DispatchQueue.main.async {
            self.contentView.backgroundColor = self.color
        }
        onTap?(tag)
    }
}
