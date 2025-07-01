//
//  EventRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

protocol EventRemoteStore {
    func fetch() async throws -> [EventRemote]
    func save(_ event: EventRemote) async throws -> [EventRemote]
    func update(_ event: EventRemote) async throws -> [EventRemote]
    func delete(_ event: EventRemote) async throws -> [EventRemote]
    func deleteAll() async throws -> [EventRemote]
}
