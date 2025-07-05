//
//  EventOverrideLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

@MainActor
protocol EventOverrideLocalStore {
    func fetchAll() throws -> [EventOverrideLocal]
    func fetch(for eventId: UUID) throws -> [EventOverrideLocal]
    func save(_ override: EventOverrideLocal) throws
    func update(_ override: EventOverrideLocal) throws
    func delete(_ override: EventOverrideLocal) throws
    func deleteAll() throws
}
