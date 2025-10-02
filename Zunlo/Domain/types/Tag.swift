//
//  Tag.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/26/25.
//

import SwiftUI
import GlowUI

public struct Tag: Identifiable, Equatable, Hashable, Codable {
    public let id: UUID
    public var text: String
    public var color: String
    public var selected: Bool

    public init(id: UUID, text: String, color: String, selected: Bool) {
        self.id = id
        self.text = text
        self.color = color
        self.selected = selected
    }
    
    public init(text: String) {
        self.id = UUID()
        self.text = text
        self.color = ""
        self.selected = false
    }
    
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
