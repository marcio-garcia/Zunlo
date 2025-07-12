//
//  ChatLocalStore.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

protocol ChatLocalStore {
    func fetchAll() async throws -> [ChatMessage]
    func save(_ message: ChatMessage) async throws
    func deleteAll() async throws
}
