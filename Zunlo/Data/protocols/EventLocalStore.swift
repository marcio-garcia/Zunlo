//
//  EventLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/29/25.
//

protocol EventLocalStore {
    func fetch() throws -> [EventLocal]
    func save(_ event: EventLocal) throws
    func update(_ event: EventLocal) throws
    func delete(_ event: EventLocal) throws
    func deleteAll() throws
}
