//
//  OpenAIOutputItem.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/5/25.
//

import Foundation

// MARK: - OpenAIOutputItem
struct OpenAIOutputItem: Codable {
    let type: String
    let sequenceNumber, outputIndex: Int
    let item: OpenAIItem

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceNumber = "sequence_number"
        case outputIndex = "output_index"
        case item
    }
}

// MARK: - Item
struct OpenAIItem: Codable {
    let id, type, status: String
    let content: [OpenAIContent]
    let role: String
}

// MARK: - Content
struct OpenAIContent: Codable {
    let type: String
    let text: String
}
