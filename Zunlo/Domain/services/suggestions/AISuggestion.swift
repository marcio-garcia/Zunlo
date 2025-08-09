//
//  AISuggestion.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/9/25.
//

import Foundation

public struct AISuggestionCTA: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let perform: @Sendable () -> Void
    
    public static func == (lhs: AISuggestionCTA, rhs: AISuggestionCTA) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
    }
}

public struct AISuggestion: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let detail: String
    public let reason: String
    public let ctas: [AISuggestionCTA]
    public let telemetryKey: String
    public let score: Int                     // simple ranking score
}

/// Strategy interface for generating one suggestion from a snapshot.
public protocol AISuggester {
    func suggest(context: AIContext) -> AISuggestion?
}
