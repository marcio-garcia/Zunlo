//
//  AISuggestionCTA.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

import SwiftUI

public struct AISuggestionCTA: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var title: String

    // Legacy/plain handler (still supported)
    private var plainHandler: (@MainActor @Sendable () -> Void)?

    // Store-aware handler (preferred for tool runs)
    private var toolHandler: (@MainActor @Sendable (_ store: ToolExecutionStore) -> Void)?

    // Existing initializer continues to work
    public init(
        title: String,
        perform: @escaping @MainActor @Sendable () -> Void
    ) {
        self.title = title
        self.plainHandler = perform
        self.toolHandler = nil
    }

    // New initializer for ToolExecutionStore-backed runs
    public init(
        title: String,
        run: @escaping @MainActor @Sendable (_ store: ToolExecutionStore) -> Void
    ) {
        self.title = title
        self.toolHandler = run
        self.plainHandler = nil
    }

    // Callers that have a store should prefer this
    @MainActor
    public func perform(using store: ToolExecutionStore) {
        if let toolHandler { toolHandler(store) }
        else { plainHandler?() }
    }

    // Back-compat call site (no store available)
    @MainActor
    public func perform() { plainHandler?() }
    
    public static func == (lhs: AISuggestionCTA, rhs: AISuggestionCTA) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
    }
}

