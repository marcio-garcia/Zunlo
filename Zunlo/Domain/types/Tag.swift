//
//  Tag.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/26/25.
//

import UIKit

struct Tag: Identifiable, Equatable, Hashable {
    let id: UUID
    var text: String
    var color: UIColor
    var selected: Bool = false
    
    init(
        id: UUID = UUID(),
        text: String,
        color: UIColor = .systemGray5,
        selected: Bool = false
    ) {
        self.id = id
        self.text = text
        self.color = color
        self.selected = selected
    }
}
