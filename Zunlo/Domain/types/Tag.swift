//
//  Tag.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/26/25.
//

import SwiftUI

struct Tag: Identifiable, Equatable, Hashable {
    let id: UUID
    var text: String
    var color: Color
    var selected: Bool = false
    
    init(
        id: UUID = UUID(),
        text: String,
        color: Color = Color.secondary,
        selected: Bool = false
    ) {
        self.id = id
        self.text = text
        self.color = color
        self.selected = selected
    }
}
