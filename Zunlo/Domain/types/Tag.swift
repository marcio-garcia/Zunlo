//
//  Tag.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/26/25.
//

import SwiftUI

struct Tag: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var text: String
    var color: String
    var selected: Bool
    
//    init(
//        id: UUID = UUID(),
//        text: String,
//        color: Color = Color.secondary,
//        selected: Bool = false
//    ) {
//        self.id = id
//        self.text = text
//        self.color = color
//        self.selected = selected
//    }
    
    static func toTag(tags: [String]) -> [Tag] {
        tags.map { tag in
            return Tag(
                id: UUID(),
                text: tag,
                color: Theme.highlightColor(for: tag),
                selected: false
            )
        }
    }
}
