//
//  EventRemoteStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

protocol EventRemoteStore {
    func fetch() async throws -> [EventRemote]
    func save(_ event: EventRemote) async throws
    func update(_ event: EventRemote) async throws
    func delete(_ event: EventRemote) async throws
    func deleteAll() async throws
}
