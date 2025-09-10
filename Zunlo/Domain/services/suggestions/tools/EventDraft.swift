//
//  EventDraft.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

// MARK: - Drafts to be mapped to real models

import Foundation

public struct EventDraft: Sendable {
    public var id: UUID?
    public var userId: UUID
    public var title: String
    public var start: Date
    public var end: Date
    public var notes: String?
    public var linkedTaskId: UUID? // optional cross-link
}

public struct PrepPackTemplate {
    public init(items: [String] = ["Review agenda", "Collect docs", "Pack charger"]) {
        self.items = items
    }
    
    public var items: [String] = ["Review agenda", "Collect docs", "Pack charger"]
}
