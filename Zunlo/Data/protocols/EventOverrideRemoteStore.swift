//
//  EventOverrideRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import Foundation

protocol EventOverrideRemoteStore {
    func fetchAll() async throws -> [EventOverrideRemote]
    func fetch(for eventId: UUID) async throws -> [EventOverrideRemote]
    func save(_ override: EventOverrideRemote) async throws -> [EventOverrideRemote]
    func update(_ override: EventOverrideRemote) async throws -> [EventOverrideRemote]
    func delete(_ override: EventOverrideRemote) async throws -> [EventOverrideRemote]
}
