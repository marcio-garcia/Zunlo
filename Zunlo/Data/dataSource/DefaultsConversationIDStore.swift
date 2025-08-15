//
//  DefaultsConversationIDStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

// MARK: - Light defaults cache for fast startup (optional but handy)

import Foundation

public protocol ConversationIDStore {
    func getOrCreate() throws -> UUID
    func reset()
}

public final class DefaultsConversationIDStore: ConversationIDStore {
    static let key = "zunlo.currentConversationId"
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func getOrCreate() throws -> UUID {
        if let raw = defaults.string(forKey: Self.key), let id = UUID(uuidString: raw) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: Self.key)
        return id
    }

    public func reset() { defaults.removeObject(forKey: Self.key) }
}
