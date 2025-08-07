//
//  AddTagCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import UIKit

class AddTagCell: UICollectionViewCell, UITextFieldDelegate {
    static let reuseIdentifier = "AddTagCell"

    private let textField = UITextField()
    var onAdd: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        textField.placeholder = "Add tag"
        textField.font = AppFontStyle.caption.uiFont()
        textField.delegate = self
        textField.returnKeyType = .done

        contentView.addSubview(textField)
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = UIColor.systemGray4 // TODO: Create theme colors for UIColor

        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text, !text.isEmpty {
            onAdd?(text)
            textField.text = ""
        }
        return true
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        print("text: \(textField.text)")
    }
}
